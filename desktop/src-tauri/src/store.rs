use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::HashSet;
use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::thread;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use time::OffsetDateTime;

const FILE: &str = "orion.json";
const LOCK: &str = "orion.lock";
const WORKSPACES: &str = "workspaces.json";
const BACKUPS: &str = "backups";
static SEQUENCE: AtomicU64 = AtomicU64::new(0);

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
pub struct Workspace {
    pub name: String,
    pub label: String,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
pub struct WorkspaceList {
    pub active: String,
    pub workspaces: Vec<Workspace>,
}

fn error(context: &str, err: impl std::fmt::Display) -> String {
    format!("{context}: {err}")
}

fn data_dir() -> Result<PathBuf, String> {
    if let Some(configured) = std::env::var_os("ORION_DATA_DIR") {
        return Ok(PathBuf::from(configured));
    }
    let home = std::env::var_os("HOME").ok_or("HOME is not set")?;
    Ok(PathBuf::from(home).join("Library/Application Support/Orion"))
}

fn valid_name(name: &str) -> bool {
    !name.is_empty()
        && name
            .bytes()
            .all(|byte| byte.is_ascii_lowercase() || byte.is_ascii_digit() || byte == b'-')
}

fn workspace_dir(root: &Path, name: &str) -> PathBuf {
    if name == "default" {
        root.to_path_buf()
    } else {
        root.join("workspaces").join(name)
    }
}

fn default_workspaces() -> WorkspaceList {
    WorkspaceList {
        active: "default".into(),
        workspaces: vec![Workspace {
            name: "default".into(),
            label: "Default".into(),
        }],
    }
}

fn workspaces_at(root: &Path) -> Result<WorkspaceList, String> {
    let path = root.join(WORKSPACES);
    if !path.exists() {
        return Ok(default_workspaces());
    }
    let raw = fs::read(&path).map_err(|err| error("read workspaces", err))?;
    let stored: WorkspaceList =
        serde_json::from_slice(&raw).map_err(|err| error("parse workspaces", err))?;
    let mut result = default_workspaces();
    let mut seen = HashSet::from([String::from("default")]);
    for entry in stored.workspaces {
        if !valid_name(&entry.name) || entry.label.trim().is_empty() {
            return Err(format!("invalid workspace: {}", entry.name));
        }
        if entry.name == "default" {
            result.workspaces[0] = entry;
        } else if seen.insert(entry.name.clone()) {
            result.workspaces.push(entry);
        }
    }
    if !result
        .workspaces
        .iter()
        .any(|entry| entry.name == stored.active)
    {
        return Err(format!("unknown active workspace: {}", stored.active));
    }
    result.active = stored.active;
    Ok(result)
}

fn known_workspace(root: &Path, name: &str) -> Result<WorkspaceList, String> {
    let list = workspaces_at(root)?;
    if !valid_name(name) || !list.workspaces.iter().any(|entry| entry.name == name) {
        return Err(format!("unknown workspace: {name}"));
    }
    Ok(list)
}

fn read_at(root: &Path, name: &str) -> Result<Option<Value>, String> {
    known_workspace(root, name)?;
    let path = workspace_dir(root, name).join(FILE);
    if !path.exists() {
        return Ok(None);
    }
    let raw = fs::read(&path).map_err(|err| error("read canvas", err))?;
    serde_json::from_slice(&raw)
        .map(Some)
        .map_err(|err| error("parse canvas", err))
}

fn stamp(now: OffsetDateTime) -> String {
    format!(
        "{:04}{:02}{:02}T{:02}{:02}{:02}Z",
        now.year(),
        now.month() as u8,
        now.day(),
        now.hour(),
        now.minute(),
        now.second()
    )
}

fn backup_stamp(name: &str) -> Option<&str> {
    let (_, suffix) = name.strip_prefix("orion-r")?.split_once('-')?;
    let value = suffix.strip_suffix(".json")?;
    (value.len() == 16 && value.as_bytes().get(8) == Some(&b'T') && value.ends_with('Z'))
        .then_some(value)
}

fn backup_current(file: &Path) -> Result<(), String> {
    if !file.exists() {
        return Ok(());
    }
    let now = OffsetDateTime::now_utc();
    let folder = file
        .parent()
        .ok_or("canvas path has no parent")?
        .join(BACKUPS);
    fs::create_dir_all(&folder).map_err(|err| error("create backups", err))?;
    let previous: Value =
        serde_json::from_slice(&fs::read(file).map_err(|err| error("read canvas", err))?)
            .map_err(|err| error("parse canvas", err))?;
    let revision = previous["revision"]
        .as_u64()
        .ok_or("canvas has no revision")?;
    let backup = folder.join(format!("orion-r{revision}-{}.json", stamp(now)));
    let mut target = OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&backup)
        .map_err(|err| error("create backup", err))?;
    let mut source = fs::File::open(file).map_err(|err| error("open canvas", err))?;
    std::io::copy(&mut source, &mut target).map_err(|err| error("copy backup", err))?;

    let hour_cutoff = stamp(now - time::Duration::hours(1));
    let day_cutoff = stamp(now - time::Duration::days(29));
    let current = stamp(now);
    let mut entries = Vec::new();
    for entry in fs::read_dir(&folder).map_err(|err| error("list backups", err))? {
        let entry = entry.map_err(|err| error("read backup entry", err))?;
        if !entry
            .file_type()
            .map_err(|err| error("read backup type", err))?
            .is_file()
        {
            continue;
        }
        let name = entry.file_name().to_string_lossy().into_owned();
        if let Some(time) = backup_stamp(&name) {
            entries.push((time.to_owned(), name, entry.path()));
        }
    }
    entries.sort_by(|a, b| b.0.cmp(&a.0).then_with(|| b.1.cmp(&a.1)));
    let mut kept_days = HashSet::new();
    for (time, _, path) in entries {
        let day = &time[..8];
        let in_range = day >= &day_cutoff[..8] && day <= &current[..8] && time <= current;
        if time >= hour_cutoff && time <= current {
            if in_range {
                kept_days.insert(day.to_owned());
            }
        } else if in_range && kept_days.insert(day.to_owned()) {
            continue;
        } else {
            fs::remove_file(path).map_err(|err| error("prune backup", err))?;
        }
    }
    Ok(())
}

fn atomic_write(path: &Path, value: &Value) -> Result<(), String> {
    let sequence = SEQUENCE.fetch_add(1, Ordering::Relaxed);
    let temporary = path.with_extension(format!("json.tmp.{}.{}", std::process::id(), sequence));
    let bytes = serde_json::to_vec_pretty(value).map_err(|err| error("serialize canvas", err))?;
    let mut file =
        fs::File::create(&temporary).map_err(|err| error("create temporary canvas", err))?;
    file.write_all(&bytes)
        .map_err(|err| error("write temporary canvas", err))?;
    file.sync_all()
        .map_err(|err| error("sync temporary canvas", err))?;
    if let Err(err) = backup_current(path) {
        eprintln!("[orion] backup skipped: {err}");
    }
    fs::rename(&temporary, path).map_err(|err| {
        let _ = fs::remove_file(&temporary);
        error("replace canvas", err)
    })
}

fn write_workspaces(root: &Path, list: &WorkspaceList) -> Result<(), String> {
    fs::create_dir_all(root).map_err(|err| error("create data directory", err))?;
    let path = root.join(WORKSPACES);
    let sequence = SEQUENCE.fetch_add(1, Ordering::Relaxed);
    let temporary = root.join(format!(
        "workspaces.json.tmp.{}.{}",
        std::process::id(),
        sequence
    ));
    let bytes =
        serde_json::to_vec_pretty(list).map_err(|err| error("serialize workspaces", err))?;
    fs::write(&temporary, bytes).map_err(|err| error("write workspaces", err))?;
    fs::rename(&temporary, &path).map_err(|err| error("replace workspaces", err))
}

struct LockGuard(PathBuf);

impl Drop for LockGuard {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}

fn acquire(dir: &Path) -> Result<LockGuard, String> {
    let lock = dir.join(LOCK);
    let deadline = Instant::now() + Duration::from_secs(5);
    loop {
        match fs::create_dir(&lock) {
            Ok(()) => {
                let guard = LockGuard(lock.clone());
                let now = SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .map_err(|err| error("clock", err))?
                    .as_secs();
                fs::write(lock.join("owner"), format!("{} {now}", std::process::id()))
                    .map_err(|err| error("write lock owner", err))?;
                return Ok(guard);
            }
            Err(err) if err.kind() == std::io::ErrorKind::AlreadyExists => {
                let now = SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .map_err(|err| error("clock", err))?
                    .as_secs();
                let owner = fs::read_to_string(lock.join("owner")).unwrap_or_default();
                let started = owner
                    .split_whitespace()
                    .nth(1)
                    .and_then(|value| value.parse::<u64>().ok());
                if started.is_some_and(|stamp| now.saturating_sub(stamp) > 30) {
                    fs::remove_dir_all(&lock).map_err(|err| error("reclaim stale lock", err))?;
                    continue;
                }
                if Instant::now() >= deadline {
                    return Err(format!("timed out waiting for {}", lock.display()));
                }
                thread::sleep(Duration::from_millis(50));
            }
            Err(err) => return Err(error("create canvas lock", err)),
        }
    }
}

fn save_at(
    root: &Path,
    workspace: &str,
    base_revision: Option<u64>,
    saved: Value,
) -> Result<Value, String> {
    let list = known_workspace(root, workspace)?;
    if list.active != workspace {
        return Ok(json!({ "ok": false, "conflict": true }));
    }
    let input = saved.as_object().ok_or("saved canvas must be an object")?;
    if !input.get("nodes").is_some_and(Value::is_array)
        || !input.get("links").is_some_and(Value::is_array)
    {
        return Err("saved canvas needs nodes and links arrays".into());
    }
    let dir = workspace_dir(root, workspace);
    fs::create_dir_all(&dir).map_err(|err| error("create workspace directory", err))?;
    let _lock = acquire(&dir)?;
    if workspaces_at(root)?.active != workspace {
        return Ok(json!({ "ok": false, "conflict": true }));
    }
    let file = dir.join(FILE);
    let current = if file.exists() {
        let raw = fs::read(&file).map_err(|err| error("read canvas", err))?;
        Some(serde_json::from_slice::<Value>(&raw).map_err(|err| error("parse canvas", err))?)
    } else {
        None
    };
    let revision = current.as_ref().and_then(|doc| doc["revision"].as_u64());
    if revision != base_revision {
        return Ok(json!({ "ok": false, "conflict": true }));
    }
    let mut next = current
        .and_then(|doc| doc.as_object().cloned())
        .unwrap_or_else(|| {
            json!({ "version": 1, "settings": { "githubOwner": "flipbook-labs" } })
                .as_object()
                .unwrap()
                .clone()
        });
    let new_revision = revision.map_or(0, |value| value + 1);
    next.insert("revision".into(), json!(new_revision));
    for field in ["nodes", "links", "stickers", "stickerLoadout"] {
        if let Some(value) = input.get(field) {
            next.insert(field.into(), value.clone());
        }
    }
    atomic_write(&file, &Value::Object(next))?;
    Ok(json!({ "ok": true, "revision": new_revision }))
}

fn create_workspace_at(root: &Path, name: &str, label: &str) -> Result<WorkspaceList, String> {
    if !valid_name(name) || label.trim().is_empty() {
        return Err("workspace needs a lowercase name and nonempty label".into());
    }
    let mut list = workspaces_at(root)?;
    if list.workspaces.iter().any(|entry| entry.name == name) {
        return Err(format!("workspace already exists: {name}"));
    }
    let dir = workspace_dir(root, name);
    fs::create_dir_all(dir.parent().ok_or("workspace has no parent")?)
        .map_err(|err| error("create workspace parent", err))?;
    fs::create_dir(&dir).map_err(|err| error("create workspace", err))?;
    atomic_write(
        &dir.join(FILE),
        &json!({ "version": 1, "revision": 0, "settings": { "githubOwner": "flipbook-labs" }, "nodes": [], "links": [] }),
    )?;
    list.workspaces.push(Workspace {
        name: name.into(),
        label: label.into(),
    });
    write_workspaces(root, &list)?;
    Ok(list)
}

pub fn workspaces() -> Result<WorkspaceList, String> {
    workspaces_at(&data_dir()?)
}

pub fn set_active_workspace(name: &str) -> Result<WorkspaceList, String> {
    let root = data_dir()?;
    let mut list = known_workspace(&root, name)?;
    if list.active != name {
        list.active = name.into();
        write_workspaces(&root, &list)?;
    }
    Ok(list)
}

pub fn create_workspace(name: &str, label: &str) -> Result<WorkspaceList, String> {
    create_workspace_at(&data_dir()?, name, label)
}

pub fn load(workspace: &str) -> Result<Option<Value>, String> {
    read_at(&data_dir()?, workspace)
}

pub fn revision() -> Result<Option<u64>, String> {
    let root = data_dir()?;
    let active = workspaces_at(&root)?.active;
    Ok(read_at(&root, &active)?.and_then(|doc| doc["revision"].as_u64()))
}

pub fn save(workspace: &str, base_revision: Option<u64>, saved: Value) -> Result<Value, String> {
    save_at(&data_dir()?, workspace, base_revision, saved)
}

#[cfg(test)]
mod tests {
    use super::*;

    struct TestDir(PathBuf);

    impl TestDir {
        fn new() -> Self {
            let id = SEQUENCE.fetch_add(1, Ordering::Relaxed);
            let dir = std::env::temp_dir()
                .join(format!("orion-native-store-{}-{id}", std::process::id()));
            fs::create_dir(&dir).unwrap();
            Self(dir)
        }

        fn path(&self) -> &Path {
            &self.0
        }
    }

    impl Drop for TestDir {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    #[test]
    fn saves_the_shared_file_with_revisions_and_preserves_other_fields() {
        let folder = TestDir::new();
        let root = folder.path();
        assert!(read_at(root, "default").unwrap().is_none());
        let first = save_at(
            root,
            "default",
            None,
            json!({ "nodes": [], "links": [], "stickers": [] }),
        )
        .unwrap();
        assert_eq!(first, json!({ "ok": true, "revision": 0 }));
        let mut doc = read_at(root, "default").unwrap().unwrap();
        doc["custom"] = json!("keep me");
        fs::write(root.join(FILE), serde_json::to_vec(&doc).unwrap()).unwrap();
        let stale = save_at(root, "default", None, json!({ "nodes": [], "links": [] })).unwrap();
        assert_eq!(stale, json!({ "ok": false, "conflict": true }));
        let next = save_at(
            root,
            "default",
            Some(0),
            json!({ "nodes": [1], "links": [], "stickers": [2] }),
        )
        .unwrap();
        assert_eq!(next, json!({ "ok": true, "revision": 1 }));
        let stored = read_at(root, "default").unwrap().unwrap();
        assert_eq!(stored["custom"], "keep me");
        assert_eq!(stored["stickers"], json!([2]));
        assert!(root.join(BACKUPS).read_dir().unwrap().next().is_some());
        assert!(!root.join(LOCK).exists());
    }

    #[test]
    fn workspaces_keep_their_canvases_separate() {
        let folder = TestDir::new();
        let root = folder.path();
        let list = create_workspace_at(root, "ideas", "Ideas").unwrap();
        assert_eq!(list.active, "default");
        assert_eq!(read_at(root, "ideas").unwrap().unwrap()["revision"], 0);
        assert_eq!(
            save_at(root, "ideas", Some(0), json!({ "nodes": [1], "links": [] })).unwrap()
                ["conflict"],
            true
        );
        let mut list = workspaces_at(root).unwrap();
        list.active = "ideas".into();
        write_workspaces(root, &list).unwrap();
        assert_eq!(
            save_at(root, "ideas", Some(0), json!({ "nodes": [1], "links": [] })).unwrap()["ok"],
            true
        );
        assert!(read_at(root, "default").unwrap().is_none());
        assert_eq!(
            read_at(root, "ideas").unwrap().unwrap()["nodes"],
            json!([1])
        );
    }
}
