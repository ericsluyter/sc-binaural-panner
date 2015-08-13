/*
Mockup of BinauralPanner and BinauralPannerGUI classes
© 2015 by Eric Sluyter

Before you execute the following code, make sure:
1. You have fully installed the Ambisonic Toolkit. 
   (http://www.ambisonictoolkit.net/)
2. You have placed the accompanying class BParaSpace.sc in your Extensions 
   directory.
3. The accompanying MCmockup.scd and VCmockup.scd are placed in the same 
   directory as this file.
*/

// test whether BParaSpace was installed correctly, if not you will see
// an error when you execute this line
BParaSpace

// First you have to load the mockups of the view and panner classes
["MCmockup.scd", "VCmockup.scd"].collect(PathName(thisProcess.nowExecutingPath).pathOnly +/+ _).do { |fn| File.open(fn, "r").readAllString.interpret.close };

// Now you can initialize the panner and gui
~panner.panner_init; // will be equivalent to ~panner = BinauralPanner.new
// If you want the window to be always on top:
~panner_view.view_init(~panner); // will be equivalent to BinauralPannerGUI.new(~panner)
// Otherwise,
~panner_view.view_init(~panner, false);

/*
From here you can either do things programmatically or through the GUI.
I have found that I like using a combination of both. When you operate
programmatically the changes are immediately visible in the GUI which is
helpful feedback even if you don't want to work with the GUI directly.

Unfortunately, the save, load, and reset buttons don't work yet.
*/


// ----- LISTENER -----

// Change the listener's position
~panner.listener_azimuth_(-pi/2);


// ----- ROOM REFLECTIONS -----

// Change the reverb of the room (make_verb actually replaces what was
// there before, perhaps should be called set_verb or verb_ or something)
// Supply a function given a stereo audio-rate argument and returning
// a stereo reverb signal
~panner.make_verb({ |in| LPF.ar(FreeVerb2.ar(in[0], in[1], 1, 0.7, 0.7), 8000); });
// Adjust the reverb send level as a function of distance from sound
// source to listener, supply a function given a distance argument and
// returning a reverb send amplitude. Here, the farther away a source gets
// from the listener the more reverb is applied.
~panner.verb_sendlevel_({ |distance| distance.expexp(0.5, 20, 0.1, 1) });
// Adjust the overal room reverb level
~panner.verb_amp_(0.25);


// ----- SOUND SOURCES -----

// Create a new sound source
~panner.make_src();
// You can now move it around in the GUI and hear what happens.

// As you see from the GUI, it is given a default name; change that with:
~panner.name_(0, "Sin droplets");
// As you hear, the default sound source is pink noise; change that with:
~panner.src_(0, { SinOsc.ar(LFNoise2.ar(10).exprange(300, 8000)) * Decay.ar(Dust2.ar(10), LFNoise2.kr(1).exprange(0.01, 0.1)) * 0.5; });
// Each sound source is actually a NodeProxy, and you can assign it any
// source that a NodeProxy will accept:
SynthDef(\sindrop, {|freq, out| Out.ar(out, SinOsc.ar(freq) * EnvGen.kr(Env.perc, 1, 0.1, doneAction:2)) }).add;
~panner.src_(0,  Pbind(\instrument, \sindrop, \note, Pwhite(0, 12), \dur, Pwhite(0.1, 0.3)));

// You can move it around programmatically with:
~panner.azimuth_(0, pi);
~panner.distance_(0, 10);

// The first argument is an index, so if you make a second source:
~panner.make_src();
// You can move it like so:
~panner.azimuth_(1, -pi/4);
~panner.distance_(1, 12);

// Distance and azimuth are actually also NodeProxies, so you can assign
// them any source a NodeProxy will accept:
~panner.azimuth_(0, { LFTri.kr(0.1) * pi });
~panner.distance_(0, { SinOsc.kr(0.13).range(0.5, 10) });

// Because they are NodeProxies, you have to access them asynchronously,
// like so: (watch the Post window)
~panner.get_azimuth(0, { |val| val.postln });
~panner.get_distance(0, { |val| val.postln });

// If you want to know what source indexes are currently being used, look at:
~panner.src_ids;


// ----- CLEANUP -----

// To free sources, use the following:
~panner.free_src(1);
~panner.free_src(0);

// This frees the whole deal (will be equivalent to ~panner.free and
// ~panner_view.free in the real BinauralPanner class)
~panner_view.free_model;
~panner.free_model;
