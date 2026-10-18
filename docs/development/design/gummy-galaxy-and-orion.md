# Gummy Galaxy and Orion

This page is a brain dump, spoken out loud so we can think on it. It stays close to how it was said, tidied up a little, and ends with the direction we drew from it.

## Gummy Galaxy grew out of Orion

Gummy Galaxy is kind of an extension of Orion. Orion came about because I wanted to make something really fun and charming, with a lot of personality. It felt like a video game, and it pulled in a bunch of things I care about. Larger design iterations have started making their way into Orion's repository as part of this documentation site, and I want to put together the same kind of context for Gummy Galaxy.

I want Gummy Galaxy to be a fun organization, a place where I can host my own creations to my heart's content, Orion among them, and pull them together under one gummy galaxy. Part of that is figuring out what qualifies something to belong there, or at least to be an extension of it. Parts of this could become the organization's profile README, in its `.github` repository, to describe what Gummy Galaxy is.

It's funny, because Orion isn't even in the organization yet, and I'm already setting classifiers for what belongs there. The things in it right now probably wouldn't pass them, except that they're tied to Orion. Artemis is the performance box. It's sitting right to my left, and it exists just to run performance tests for Orion. It's still part of Gummy Galaxy, because in that regard it just makes sense.

## Luau at the center

The thesis of Gummy Galaxy is that it's a home for things that are primarily Luau. I don't think that's been written down anywhere yet.

Luau is very near and dear to my heart. I've been programming in Lua, no U at the end, since I was about twelve or thirteen. It was the first programming language I ever started with. I think what the folks on the Luau team do is wonderful, and Luau is finally getting a package manager that people are already adopting. [Lute](https://github.com/luau-lang/lute) is a Luau runtime, and Loom is the package manager built into it.

We could be about to see an incredibly flourishing community spring up. Without a package manager, Luau projects don't stitch together the way the JavaScript community's do, where npm lets a breadth of projects combine in new and unique permutations to make new and unique software. Without a way to distribute work, Luau doesn't really have anywhere to go. Same for Lua: it had LuaRocks, the equivalent to Loom, but I never got that working on a Windows machine. It was a nightmare. So far Loom works out of the box, so I'm much happier already.

I want Gummy Galaxy positioned for that ecosystem and for broad Luau adoption, with Rust as a supporting language. I want to embed Luau in things, like we already do in Orion, where most of the brain is Luau.

## Room for other people's work

I'd like to open Gummy Galaxy up to the community and support people in different ways: supporting other organizations doing cool things in Luau open source, welcoming contributors, or letting projects we believe in host their work in the organization. These are different ways of gathering really cool Luau projects into one fun home that uplifts everything and everyone that interacts with it, as best it can.

That could mean both bringing work in and supporting it where it lives. Someone without a prominent presence on their own GitHub account might bring their repository in, or we might spotlight it in other ways. The Rojo organization is one example of a group that could be supported in some way if it ever needed it. Rojo has done so much for open source, mostly around deserializing the RBXM format, and it made the jump to using Git to version Roblox projects possible at all, because there's now a reliable way to serve that work right into Roblox Studio. It might be smaller organizations that are just spinning up, too. That's the general idea.

None of our projects are public yet, so all of this is a direction rather than something that exists today.

## A fun space

I want it to be a fun space. That's why I'm leaning so heavily into the atmosphere of gummies and candy, and of toys: little things you can play with, like minigames built into Orion. Things that take some of the gloom out of the day, in one way or another, as best a piece of software or a Luau package can. That's the ethos of Gummy Galaxy and what I want it to become.

## Orion as a game

Orion was designed to feel like a game in a lot of ways. That's why I've leaned into the [vibrant color scheme](/development/design/themes-and-skins) to give it more personality, and into the [trading card skin](/development/design/cards). I've used both as my daily drivers.

A lot of older issues talk about [a currency system](https://github.com/vocksel/orion/issues/9): as you complete tasks, like moving a card to done, you get points. They could accumulate somewhere, and maybe you could spend them on unlocking new Orion themes or skins, or find some way to level up. I don't know yet.

The idea is to take the process of pulling lots and lots of sources of information onto one canvas, and make it fun for a person to learn, interpret, understand, play with, and really get hands-on with.

## Learning a graph by hand

I'm a very hands-on person. Something I've found with Orion is that I haven't been happy with any of the reflow mechanics we've tried. None of them work the way I expect, and I'm realizing there may be no way for them to flow the way that would make sense to me. A solid base reflow is good and fine, but even that isn't the best for me to interpret until I start getting into the graph.

I look at each card, move it around, and watch where the arrows go and how they move: where things are in relation to where I am now, and what connects everything together. The hands-on movement of grabbing a card already becomes data for me to take in, so I can start making connections. From there I branch out and look for the cards related to it, usually the direct connections with arrows, sometimes the dotted relates-to links. Then I work with just those and bring them to a new area that makes sense, so I can think about that blob in isolation.

One of the issues talks about [floating polygons](https://github.com/vocksel/orion/issues/368) that form around cards to make regions, localized groups of just those cards. It's the same kind of concept here, but made on the fly, as I'm selecting and dragging.

I can even picture the scroll wheel, or the whole mouse, as a painting tool: scroll in and out to change the brush radius and its intensity, then use it almost like a magnet to drag cards around, pull some in, and shake off others, so I keep only the ones I actually mean to. Some intuitive way to work with the unruly blob of cards that's always there after a reflow, or that builds up over time as new cards land on the canvas. New cards are frustrating in particular. I don't want to reflow the canvas because I've already got it how I want, but now there are all these cards stacked in the top-right corner.

## Selecting and getting around

Card selection deserves [its own issue](https://github.com/vocksel/orion/issues/456). I'd love to dig into it and figure out how to make a single selection tool that's intuitive and makes the canvas much easier to navigate.

Having to hold a button at all to move around the canvas, like the middle click, really sucks. I don't like pressing it. I'd love a different default. Maybe holding right click lets you drag around, if we can get away with that without the context menu becoming a problem. Maybe you hold a button and the canvas follows the mouse. I need something better for selection, for movement, for getting around the canvas, and for being able to arbitrarily grab parts of the board and make sense of them. Almost like I could use my hands to pluck things out of the air, form little groups out of them, and orchestrate them in three-dimensional space, even though we're working on a two-dimensional board.

I'd love to know more about gestures, and about making them feel good and intuitive both for someone with my kind of brain and for a more traditional brain. Maybe we need an autism mode.

I want to prototype it, so I can quite literally get hands-on with it and see which one feels right. Very simple cards would do, matching the trading card skin's dimensions on a little fake board, so we can try different tools for selecting things and use modifier keys to change how they behave. It needs a lot of on-the-fly handling to feel good, especially since people will be using just a keyboard and a mouse. Ideally it's mostly the mouse, pressing a modifier key here and there to change some behavior while you work, but we can do something more complex if we have to.

The selection work stays in Orion for now, since Orion is the home for all the issues at this point. It would be nice to have a central issue board for Gummy Galaxy, but I don't know if that's really a thing unless we made a repository just for issue tracking.

## Direction we drew from it

Talking it through settled a few starting points. They're suggestions to build on, not decisions.

- **What connects the projects.** It's less about shared technology than about how the projects feel: playful, charming, and exploratory, with Luau at the center. Rust tools and supporting projects like Artemis belong when they help that work flourish.
- **An honest opening for the organization.** Because nothing is public yet, a profile shouldn't promise projects people can browse today. A draft opening:

  > Gummy Galaxy is taking shape as a playful home for Luau projects. Our own projects are still in development, and we hope to share them here as they're ready. In time, we'd also like to support more Luau creators, by giving emerging projects a home or celebrating work wherever it lives.

- **A name for the mode.** "Hands-on canvas" describes the experience without assuming everyone wants the same controls.
- **Predictable gestures.** Keep each gesture visible and consistent. For example, a short right click opens the menu, a right drag always pans, and a gathering gesture previews exactly which cards it will pick up.
- **An experiment before a decision.** The prototype is a fake board where you can switch between box selection, sweeping, and plucking a card with its linked cards, then try panning and modifier keys on the same layout. It records what each gesture lets you test, without picking a winner before you've tried them.
- **A central board, maybe.** An organization-level GitHub Project can gather issues from several repositories and hold draft ideas, so a central Gummy Galaxy board wouldn't need an issue-only repository. Nothing has been set up.
