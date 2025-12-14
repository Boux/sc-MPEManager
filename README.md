## MPEManager

You can find and try these examples in examples.scd

### MPEManager.mpe()

**[EXAMPLE 1]** Basic MPE instrument

Create a basic synth for every note pressed. This example only uses the getSynth and onChange functions.

**getSynth**: creates a synth according to midi signal and map control bus to parameters
  - freq: midi note converted to Hz
  - amp: midi note velocity ranges from 0.1 to 1
  - bend: -24/+24, mapped with a NOTE-SPECIFIC control bus

**onChange**: manually handle midi control changes
  - filter_cut_ratio: mpe note timbre value from 1 to 7
  - vibrato_depth: mpe note pressure value from -0.5 to 0.5
```
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
```


### MPEManager.midi()

**[EXAMPLE 2]** Normal MIDI instrument with controls

Create a basic synth for every note pressed. This example will show how to bind a non-MPE (standard MIDI) device and its controls to the synth

**getSynth**:
  - freq: midi note converted to Hz
  - amp: midi note velocity ranges from 0.1 to 1
  - width: initialised from "fatness" value
  - bend: -2/+2, mapped with a global bend control bus
  - vibrato_depth: mapped with a global "wobble" control bus

**onChange**:
  - width: apply "fatness" value to all active synths

In this example, it would be easier to simply map the width to the "fatness" control bus, but I wanted to show an example where onChange is used for setting the value of all notes at the same time.

```
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
```
