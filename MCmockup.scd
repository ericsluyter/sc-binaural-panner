/*
BinauralPanner mockup
© 2015 by Eric Sluyter
*/

(
~panner = (
  model: nil,

  free_model: { |e|
    if (e.model.notNil) {
      e.model[\srcs].keysValuesDo { |id, src|
        e.free_src(id);
      };

      e.model[\verb_group].free;
      e.model[\verb_send].free;
      e.model[\listener_azimuth].free;

      e.model[\decoder].free;
      e.model[\encoder].free;

      e.model = nil;
    }
  },

  panner_init: { |e|
    e.free_model;

    e.model = IdentityDictionary.newFrom((
      facing_angle: 0,

      decoder: FoaDecoderKernel.newCIPIC,
      encoder: FoaEncoderKernel.newDiffuse,

      listener_azim_np: NodeProxy.control(s, 1),

      next_id: 0,
      srcs: IdentityDictionary(),
      dry_outbus: 0,

      verb_send: Bus.audio(s, 2),
      verb_sendlevel: { |distance| distance.expexp(0.5, 20, 0.5, 1) },
      verb_amp: 0.05,
      verb_func: nil,
      verb_group: Group.after(s.defaultGroup),
      verb_synth: nil,
      verb_outbus: 0
    ));

    e.make_verb();
  },

  facing_angle: { |e|
    e.model[\facing_angle];
  },
  facing_angle_: { |e, angle|
    e.model[\facing_angle] = angle;
  },

  encoder: { |e|
    e.model[\encoder];
  },
  encoder_: { |e, encoder|
    /*
    e.model[\encoder].free;
    e.model[\encoder] = encoder;
    */
    "TODO: implement encoder changes".postln;
  },
  decoder: { |e|
    e.model[\decoder];
  },
  decoder_: { |e decoder|
    /*
    e.model[\decoder].free;
    e.model[\decoder] = decoder;
    */
    "TODO: implement decoder changes".postln;
  },

  next_id: { |e|
    e.model[\next_id];
  },
  next_name: { |e|
    "Source " ++ (e.next_id + 65).asAscii;
  },
  dry_outbus: { |e|
    e.model[\dry_outbus];
  },
  dry_outbus_: { |e, dry_outbus|
    e.model[\dry_outbus] = dry_outbus;
    e.model[\srcs].do { |src|
      src[\dist_atten_np].play(dry_outbus, 2);
    };
    e.changed(\dry_outbus, dry_outbus);
  },
  src_default: { |e|
    { PinkNoise.ar(0.1) }
  },

  make_src: { |e, src = nil, azimuth = 0, distance = 2, name = nil, angle = (pi/2)|
    var new_src;
    var angle_np = NodeProxy.control(s, 1);
    var azim_np = NodeProxy.control(s, 1);
    var dist_np = NodeProxy.control(s, 1);
    var src_np = NodeProxy.audio(s, 1);
    var panner_np = NodeProxy.audio(s, 2);
    var verb_send_np = NodeProxy.audio(s, 2);
    var dist_atten_np = NodeProxy.audio(s, 2);
    var encoder = e.model[\encoder];
    var decoder = e.model[\decoder];
    var listener_azim_np = e.model[\listener_azim_np];
    var verb_sendlevel = e.model[\verb_sendlevel];

    if (name.isNil) {
      name = e.next_name;
    };
    if (src.isNil) {
      src = e.src_default;
    };

    angle_np.source = angle;
    azim_np.source = azimuth;
    dist_np.source = distance;

    src_np.source = src;
    panner_np.source = {
      var decoded;
      var in = src_np.ar(1);
      var azim = listener_azim_np.kr(1) - azim_np.kr(1);
      var distance = dist_np.kr(1);
      var angle = angle_np.kr(1);
      var encoded = FoaEncode.ar(in, encoder);

      var transformed = FoaTransform.ar(encoded, 'push', angle, azim);
      transformed = HPF.ar(transformed, 20);
      transformed = FoaTransform.ar(transformed, 'proximity', (distance - 0.5).max(0.05));

      decoded = FoaDecode.ar(transformed, decoder);
      LeakDC.ar(decoded);
    };

    verb_send_np.source = {
      var in = panner_np.ar(2);
      var distance = dist_np.kr(1);
      in * (verb_sendlevel.value(distance) ! 2);
    };

    dist_atten_np.source = {
      var decoded = panner_np.ar(2);
      var distance = dist_np.kr(1);
      var attenuation = log2(distance.max(0.5) / 0.5) * 3;
      var hf_attenuation = distance.linexp(0.1, 6, 18000, 8000);
      decoded = LPF.ar(decoded, hf_attenuation);
      decoded = (decoded * (-1 * attenuation).dbamp);
      decoded;
    };

    dist_atten_np.play(e.model[\dry_outbus], 2);
    verb_send_np.play(e.model[\verb_send].index, 2);

    new_src = IdentityDictionary.newFrom((
      name: name,
      src: src,
      angle_np: angle_np,
      azim_np: azim_np,
      dist_np: dist_np,
      src_np: src_np,
      panner_np: panner_np,
      verb_send_np: verb_send_np,
      dist_atten_np: dist_atten_np
    ));
    e.model[\srcs][e.model[\next_id]] = new_src;
    e.model[\next_id] = e.model[\next_id] + 1;
    // Update dependants
    e.changed(\srcs, nil);
  },
  free_src: { |e, id|
    var src = e.model[\srcs][id];
    src[\panner_np].stop;
    src[\panner_np].free;
    src[\src_np].free;
    src[\dist_np].free;
    src[\azim_np].free;
    src[\angle_np].free;
    e.model[\srcs][id] = nil;
    // Update dependants
    e.changed(\srcs, nil);
  },
  src_ids: { |e|
    e.model[\srcs].keys.asArray.sort;
  },

  src: { |e, id|
    e.model[\srcs][id][\src];
  },
  src_: { |e, id, src|
    e.model[\srcs][id][\src] = src;
    e.model[\srcs][id][\src_np].source = src;
  },
  get_angle: { |e, id, action|
    e.model[\srcs][id][\angle_np].bus.get(action);
  },
  angle_: { |e, id, angle|
    e.model[\srcs][id][\angle_np].source = angle;
  },
  get_azimuth: { |e, id, action|
    e.model[\srcs][id][\azim_np].bus.get(action);
  },
  azimuth_: { |e, id, azimuth|
    e.model[\srcs][id][\azim_np].source = azimuth;
  },
  get_distance: { |e, id, action|
    e.model[\srcs][id][\dist_np].bus.get(action);
  },
  distance_: { |e, id, distance|
    e.model[\srcs][id][\dist_np].source = distance;
  },
  name: { |e, id|
    e.model[\srcs][id][\name];
  },
  name_: { |e, id, name|
    e.model[\srcs][id][\name] = name;
    // update dependants
    e.changed(\srcs, nil);
  },

  get_listener_azimuth: { |e, action|
    e.model[\listener_azim_np].bus.get(action);
  },
  listener_azimuth_: { |e, azimuth|
    e.model[\listener_azim_np].source = azimuth;
  },

  verb_sendlevel: { |e|
    e.model[\verb_sendlevel];
  },
  verb_sendlevel_: { |e, verb_sendlevel|
    e.model[\verb_sendlevel] = verb_sendlevel;
    e.model[\srcs].do { |src|
      src[\verb_send_np].source = {
        var in = src[\panner_np].ar(2);
        var distance = src[\dist_np].kr(1);
        in * verb_sendlevel.value(distance);
      };
    };
  },
  verb_amp: { |e|
    e.model[\verb_amp]
  },
  verb_amp_: { |e, amp = 0.1|
    e.model[\verb_amp] = amp;
    if (e.model[\verb_synth].notNil) {
      e.model[\verb_synth].set(\amp, amp);
    };
    // Update dependants
    e.changed(\verb_amp, amp);
  },
  verb_func: { |e|
    e.model[\verb_func]
  },
  verb_func_default: { |e|
    { |in| FreeVerb2.ar(in[0], in[1], 1, 0.5, 0.5); };
  },

  make_verb: { |e, verbfunc = nil|
    if (verbfunc.notNil) {
      e.model[\verb_func] = verbfunc;
    };
    if (e.model[\verb_func].isNil) {
      e.model[\verb_func] = e.verb_func_default;
    };
    if (e.model[\verb_synth].notNil) {
      e.model[\verb_synth].free;
    };
    e.model[\verb_synth] = {
      var amp = \amp.kr(e.model[\verb_amp], 0.1);
      var in = In.ar(e.model[\verb_send], 2);
      var verb = e.model[\verb_func].value(in);
      verb * amp;
    }.play(e.model[\verb_group], e.model[\verb_outbus]);
  },

  verb_outbus: { |e|
    e.model[\verb_outbus];
  },
  verb_outbus_: { |e, verb_outbus|
    e.model[\verb_outbus] = verb_outbus;
    if (e.model[\verb_synth].notNil) {
      e.make_verb;
    };
    e.changed(\verb_outbus, verb_outbus);
  }
);
)