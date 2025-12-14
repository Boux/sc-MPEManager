// enable virtual midi driver (Linux)
// sudo modprobe snd-virmidi enable=1,1,1,1,1,1,1,1 midi_devs=1,1,1,1,1,1,1,1

// install custom classes
Quarks.install("_classes".resolveRelative);

// uninstall all custom classes
// Quarks.clear;

(
MIDIClient.init;
MIDIIn.connectAll;
);

MIDIFunc.trace(true);
MIDIFunc.trace(false);

Platform.userExtensionDir;

// list MIDI devices
MIDIClient.sources.do { |src, i| "[%] %: %\n".postf(i, src.uid, src.name) };


// simple synth with vibrato and LPF
(
SynthDef(\example, { |freq=200, bend=0, timbre=0, width=0.25, vibrato_depth=0, filter_cut_ratio=4, filter_q=0.2, gate=1, amp=1, pan=0, out=0|
  var sig, env, lfo;

  env = EnvGen.kr(Env.adsr(0.01, 0.5, 0.5, 0.1), gate, doneAction: Done.freeSelf);
  lfo = SinOsc.kr(5) * vibrato_depth;

  freq = freq * bend.lag(0.1).midiratio;

  sig = Pulse.ar(freq * lfo.midiratio, width.lag(0.1));
  sig = RLPF.ar(sig, freq * filter_cut_ratio.lag(0.1), filter_q.lag(0.1));

  sig = Pan2.ar(sig, pan);
  sig = sig * amp * env;
  Out.ar(out, sig);
}).add;
)

(
/*
--- [EXAMPLE 1] Basic MPE instrument ---

Uses MPEManager.mpe

Create a basic synth for every note pressed. This example only uses the getSynth and onChange functions.

  getSynth: creates a synth according to midi signal and map control bus to parameters
    - freq: midi note converted to Hz
    - amp: midi note velocity ranges from 0.1 to 1
    - bend: -24/+24, mapped with a NOTE-SPECIFIC control bus

  onChange: manually handle midi control changes
    - filter_cut_ratio: mpe note timbre value from 1 to 7
    - vibrato_depth: mpe note pressure value from -0.5 to 0.5
*/
try { m.free };
m = MPEManager.mpe({ |manager, note|
  var synth = Synth(\example, [
    \freq, note.num.midicps,
    \amp, note.vel.linlin(0, 127, 0.1, 1),
    \out, 2
  ]);

  // mapped to note-specific bend bus
  synth.map(\bend, note.ctl.bus(\bend));
}, { |manager, note, e|
  if (e[\timbre].notNil) {
    note.synth.set(\filter_cut_ratio, e[\timbre].linlin(-1, 1, 1, 7));
  };

  if (e[\pressure].notNil) {
    note.synth.set(\vibrato_depth, e[\pressure] / 2);
  }
});
)


(
/*
--- [EXAMPLE 2] Normal MIDI instrument with controls ---

Uses MPEManager.midi

Create a basic synth for every note pressed. This example will show how to bind a non-MPE (standard MIDI) device and its control to the synth

  getSynth:
    - freq: midi note converted to Hz
    - amp: midi note velocity ranges from 0.1 to 1
    - width: initialised from "fatness" value
    - bend: -2/+2, mapped with a global bend control bus
    - vibrato_depth: mapped with a global "wobble" control bus

  onChange:
    - width: apply "fatness" value to all active synths

In this example, it would be easier to simply map the width to the "fatness" control bus, but I wanted to show an example where onChange is used for setting the value of all notes at the same time.
*/
try { m.free };
m = MPEManager.midi({ |manager, note|
  var synth = Synth(\example, [
    \freq, note.num.midicps,
    \amp, note.vel.linlin(0, 127, 0.1, 1),
    \width, manager.ctl.value(\fatness, 0.25),
    \out, 2
  ]);

  // mapped to global bend bus
  synth.map(\bend, manager.ctl.bus(\bend));
  synth.map(\vibrato_depth, manager.ctl.bus(\wobble));

  // synth.map(\width, manager.ctl.bus(\fatness));
}, { |manager, note, e|
  // set width of all currently active notes
  if (e[\fatness].notNil) {
    manager.notes.do { |n| n.synth.set(\width, e[\fatness]); }
  }
},
bendRange: 2);

m.bind(\wobble, \control, { |note, key, val|
  m.set(\wobble, val.linlin(0, 127, 0, 1));
}, 92);

m.bind(\fatness, \control, { |note, key, val|
  m.set(\fatness, val.linlin(0, 127, 0.05, 0.5));
}, 93);
);



(
/*
--- [EXAMPLE 3] Binding to specific MIDI channel and source ---

You can specify the "chan" and "srcID" parameters to only listen to signals from a specific MIDI device and channel.

The "chan" parameter is only compatible in midi mode, not mpe mode, since mpe uses all 16 channels for polyphony.

*/
try { m.free };
m = MPEManager.midi({ |manager, note|
  Synth(\example, [
    \freq, note.num.midicps,
    \amp, note.vel.linlin(0, 127, 0.1, 1),
    \width: 0.5,
    \out, 2,
  ]);
}, chan: 2, srcID: MIDIClient.sources[4].uid);
);








/*
------------------------------------------
----------------- [DEMO] -----------------
------------------------------------------
*/

(
SynthDef(\demo, { |freq=200, atk=0.01, decay=0.5, sustain=0.5, rel=0.1, filter_atk=0.001, filter_decay=4, filter_cut=2, filter_mod=4, filter_q=0.2, bend=0, width=0.25, detune=0, vibrato_speed=5, vibrato_depth=0, harmonics_blend=0, gate=1, amp=1, pan=0, out=0|
  var sig, harmonics_sig, env, filter_env, lfo;

  env = EnvGen.kr(Env.adsr(atk, decay, sustain, rel), gate, doneAction: Done.freeSelf);
  filter_env = EnvGen.kr(Env.perc(filter_atk, filter_decay), gate);
  lfo = SinOsc.kr(vibrato_speed) * vibrato_depth;

  freq = freq * bend.lag(0.1).midiratio;
  freq = freq * lfo.midiratio;

  sig = Mix([
    Pulse.ar(freq, width.lag(0.1)),
    VarSaw.ar(freq * (100+detune/100), 0, width.lag(0.1))
  ]);

  harmonics_sig = CombLP.ar(sig, 1, 0.2, ((freq * LFNoise2.kr(1).range(-0.5.midiratio, 0.5.midiratio)) * 2).reciprocal, 0.2, 0.5);
  sig = sig.blend(harmonics_sig, harmonics_blend);

  sig = RLPF.ar(sig, (freq * filter_cut.lag(0.1)) + (freq * filter_env * filter_mod.lag(0.1)), filter_q.lag(0.1));

  sig = Pan2.ar(sig, pan);
  sig = sig * amp * env;
  Out.ar(out, sig);
}).add;

try { ~demo1.free };
~demo1 = MPEManager.mpe({ |manager, note|
  var synth = Synth(\demo, [
    \freq, note.num.midicps,
    \atk, note.vel.lincurve(0, 127, 0.5, 0.001, -10),
    \decay, 8,
    \sustain, 0.5,
    \amp, note.vel.linlin(0, 127, 0.5, 0.8),
    // \filter_atk, 1,
    \filter_mod, note.vel.linlin(0, 127, 2, 8),
    \filter_q, note.vel.linlin(0, 127, 1, 0.1),
    \detune, 50,
    \out, 2
  ]);


  // mapped to note-specific bend bus
  synth.map(\bend, note.ctl.bus(\bend));
  synth.map(\filter_cut, note.ctl.bus(\filter_cut, 2));
  synth.map(\harmonics_blend, note.ctl.bus(\harmonics_blend, 0));

  synth.map(\detune, manager.ctl.bus(\detune));
  synth.map(\width, manager.ctl.bus(\width, 0.25));
  synth.map(\vibrato_speed, manager.ctl.bus(\vibrato_speed, 5));
  synth.map(\vibrato_depth, manager.ctl.bus(\vibrato_depth, 0));
  synth;
}, { |manager, note, e|
  if (e[\timbre].notNil) {
    note.set(\filter_cut, e[\timbre].clip(0, 1).linlin(0, 1, 2, 10));
    note.set(\harmonics_blend, e[\timbre].clip(0, 1));
  };
},
srcID: MIDIClient.sources[3].uid);

~demo1.bind(\vibrato_speed, \control, { |note, key, val|
  ~demo1.set(\vibrato_speed, val.linlin(0, 127, 0.1, 8));
}, 91);

~demo1.bind(\vibrato_depth, \control, { |note, key, val|
  ~demo1.set(\vibrato_depth, val.linlin(0, 127, 0, 1));
}, 92);

~demo1.bind(\width, \control, { |note, key, val|
  ~demo1.set(\width, val.linlin(0, 127, 0.05, 0.5));
}, 93);

~demo1.bind(\detune, \control, { |note, key, val|
  ~demo1.set(\detune, val.linlin(0, 127, 0.0001, 5));
}, 94);
)


~demo1.trace = true;
~demo1.trace = false;






(
SynthDef(\weird, { |freq=200, impulse_rel=0.05, bend=0, timbre=0, comb_decay=0.1, comb_coef=0.75, gate=1, amp=1, pan=0, out=0|
  var sig, delay_line, delay_sig, impulse_env, env, lfo;

  env = EnvGen.kr(Env.adsr(0.015, 6, 0.5, 1.5), gate, doneAction: Done.freeSelf);
  impulse_env = EnvGen.kr(Env.perc(0.001, impulse_rel));

  freq = freq * bend.lag(0.25).midiratio;

  sig = WhiteNoise.ar(1!2);
  sig = RLPF.ar(sig, (freq*4) + (freq * 50.midiratio * impulse_env), 0.75, 1) * impulse_env;

  // feedback danger zone
  delay_line = LocalIn.ar(2);
  delay_sig = RLPF.ar(sig + delay_line, freq * 10);
  delay_sig = RHPF.ar(delay_sig, freq / 6);
  delay_sig = CombLP.ar(delay_sig, 1, 0.2, ((freq/8) * LFNoise2.kr(0.12).range(-36.midiratio, 36.midiratio)).reciprocal, comb_decay, comb_coef);

  sig = delay_sig;

  delay_sig = DelayC.ar(delay_sig, 1, (0.02 + (0.35 * env)) + (-0.05 * timbre), -0.5.dbamp);
  delay_sig = Limiter.ar(delay_sig);
  delay_line = LocalOut.ar(delay_sig);


  sig = Compander.ar(sig, sig, 0.05, 1, 0.1, 0, 0.1, 20);
  sig = Limiter.ar(sig);

  // sig = Pan2.ar(sig, pan);
  sig = sig * amp * env;
  Out.ar(out, sig);
}).add;


try { ~demo2.free };
~demo2 = MPEManager.mpe({ |manager, note|
  var synth = Synth(\weird, [
    \freq, note.num.midicps,
    \out, 4
  ]);

  synth.map(\bend, note.ctl.bus(\bend));
  synth.map(\timbre, note.ctl.bus(\timbre));

  synth.map(\comb_decay, manager.ctl.bus(\what1, 0.1));
  synth.map(\comb_coef, manager.ctl.bus(\what2, 0.75));
  synth.map(\impulse_rel, manager.ctl.bus(\impulse_rel, 0.05));
},
srcID: MIDIClient.sources[4].uid);


~demo2.bind(\what1, \control, { |note, key, val|
  ~demo2.set(\what1, val.linlin(0, 127, 0.01, 1));
}, 20);

~demo2.bind(\what2, \control, { |note, key, val|
  ~demo2.set(\what2, val.linlin(0, 127, 0.1, 0.99));
}, 21);

~demo2.bind(\impulse_rel, \control, { |note, key, val|
  ~demo2.set(\impulse_rel, val.linexp(0, 127, 0.01, 0.5));
}, 22);
)