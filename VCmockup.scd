/*
BinauralPannerGUI mockup
© 2015 by Eric Sluyter
*/

(
~panner_view = (
  model: nil,

  free_model: { |e|
    if (e.model.notNil) {
      e.model.window.close;
      e.model.source_map.do { |src_info|
        src_info.rout.stop;
      };
      e.model.facing_routine.stop;
      e.model.panner.removeDependant(e.model[\updater_func]);
    };
    e.model = nil;
  },

  model_init: { |e, panner|
    e.model = (
      panner: panner,
      sourcemap: [],

      width: 400,
      height: 400,
      margins: (left: 10, right: 100, top: 80, bottom: 125),

      colors: (
        bg: Color(0.06, 0, 0.13, 0.6),
        bglighter: Color(0.06, 0, 0.13, 0.55),
        bgdarker: Color(0.06, 0, 0.13, 0.2),
        grid: Color(1, 1, 1, 0.15),
        gridminor: Color(1, 1, 1, 0.05),
        listener: Color(0.9, 0.9, 1, 0.9),
        src: Color(0.2, 0.6, 0.3),
        facing: Color(0, 0.1, 0.5, 0.9),
        paraoutline: Color.white,
        parafont: Color.white,
        meternumber: Color(1, 1, 1, 0.1),
        newbutt: Color(0.5, 1, 0.6),
        editbutt: Color(0.5, 1, 1),
        delbutt: Color(1, 0.5, 0.6),
        verbedit: Color(1, 1, 0.6)
      ),
      fonts: (
        meternumber: Font('Helvetica', 9),
        title: Font('Helvetica', 40, true),
        byline: Font('Helvetica', 12, true),
        panelhead: Font('Helvetica', 16, true),
        numboxlabel: Font("Helvetica", 12, false),
        buslabel: Font('Helvetica', 12, true),
        buttontext: Font("Helvetica", 12, false)
      ),

      metersacross: 20,
      facing_angle: 0,
      facing_routine: nil,

      centerpoint: nil,
      window: nil,
      paraspace: nil,

      width_spec: ControlSpec(4, 100, \exp, units: "m"),
      width_slider: nil,
      width_numbox: nil,

      drybus_numbox: nil,
      wetbus_numbox: nil,

      save_button: nil,
      load_button: nil,
      reset_button: nil,

      new_button: nil,
      edit_button: nil,
      delete_button: nil,

      verb_spec: \amp.asSpec,
      verb_slider: nil,
      verb_numbox: nil,
      verb_button: nil,
      verb_amp: panner.verb_amp,

      verb_outbus: panner.verb_outbus,
      dry_outbus: panner.dry_outbus,

      updater_func: nil
    );

    e.model.centerpoint = (e.model.width/2)@(e.model.height/2);
  },

  view_init: { |e, panner = nil, alwaysontop = true|
    if (panner.isNil) {
      "Must supply a valid panner!".postln;
    } {
      e.free_model;
      e.model_init(panner);

      e.draw_window(alwaysontop);
      e.draw_title;
      e.draw_paraspace;
      e.draw_lowerpanel;
      e.draw_rightpanel;

      e.model.facing_routine = fork {
        loop {
          e.model.panner.get_listener_azimuth({ |val| e.update_facing_angle(val) });
          0.05.wait;
        }
      };

      e.build_source_map;

      e.model[\updater_func] = { |theChanger, what, val|
        if (what == \srcs) {
          e.build_source_map;
        };
        if (what == \verb_amp) {
          e.model.verb_amp = val;
          e.model.verb_slider.value_(e.model.verb_spec.unmap(val));
          e.model.verb_numbox.value_(val.ampdb.round(0.1));
        };
        if (what == \verb_outbus) {
          e.model.wetbus_numbox.value_(val);
        };
        if (what == \dry_outbus) {
          e.model.drybus_numbox.value_(val);
        };
      };

      e.model.panner.addDependant(e.model[\updater_func]);
    };
  },

  draw_window: { |e, alwaysontop|
    // Window!!
    e.model.window = Window("Binaural panner", Rect(
      Window.screenBounds.width - (e.model.margins.left + e.model.margins.right),
      Window.screenBounds.height,
      e.model.width + e.model.margins.left + e.model.margins.right,
      e.model.width + e.model.margins.top + e.model.margins.bottom
    ))
    .front
    .alwaysOnTop_(alwaysontop)
    .onClose_({ e.free_model });
  },

  draw_paraspace: { |e|
    var facing_point = Polar(0.4, e.model.facing_angle).asPoint;

    // ParaSpace
    e.model.paraspace = BParaSpace(e.model.window, Rect(
      e.model.margins.left,
      e.model.margins.top,
      e.model.width,
      e.model.height
    ))
    .setBackgrColor_(e.model.colors.bg)
    .setBackgrDrawFunc_({ e.draw_paraspace_bg }) // custom bg function

    // Listener node
    .createNode1(0.5, 0.5, e.model.colors.listener)
    .setNodeSize_(0, e.model.width / e.model.metersacross)
    .setNodeString_(0, "Listener")

    // Facing direction node
    .createNode1(facing_point.x + 0.5, facing_point.y + 0.5, e.model.colors.facing)
    .setNodeString_(1, "Facing direction")
    .createConnection(0, 1)

    // Aesthetics
    .setShape_("circle")
    .setOutlineColor_(e.model.colors.paraoutline)
    .setFontColor_(e.model.colors.parafont)

    // Tracking action
    .nodeTrackAction_({ |node|
      if (node.spritenum == 0) {
        e.model.paraspace.setNodeLoc1_(0, 0.5, 0.5);
      };
      if (node.spritenum == 1) {
        var angle = e.coordtopos(e.model.paraspace.getNodeLoc1(1).asPoint).theta;
        angle = e.find_closest_angle(e.model.facing_angle, angle);
        e.model.panner.listener_azimuth_(angle);
        e.model.paraspace.setNodeLoc1_(1, node.temp.x + 0.5, node.temp.y + 0.5);
      };
      if (node.spritenum >= 2) {
        var src_info = e.model.source_map[node.spritenum-2];
        var newpos = e.coordtopos(e.model.paraspace.getNodeLoc1(node.spritenum).asPoint);
        var newazim = e.find_closest_angle(src_info.azimuth, newpos.theta);
        var newdist = newpos.dist(0@0);
        var src_id = src_info.src_id;
        e.model.panner.distance_(src_id, newdist);
        e.model.panner.azimuth_(src_id, newazim);
        e.model.paraspace.setNodeLoc1_(node.spritenum, node.temp.x, node.temp.y);
      };
    });

    // Facing temp
    e.model.paraspace.paraNodes[1].temp = facing_point;
  },

  redraw_facing_angle: { |e|
    var facing_point = Polar(0.4, e.model.facing_angle).asPoint;
    e.model.paraspace.setNodeLoc1_(1, facing_point.x + 0.5, facing_point.y + 0.5);
    // Facing temp
    e.model.paraspace.paraNodes[1].temp = facing_point;
  },

  find_closest_angle: { |e, prevangle, angle|
    while {
      ((angle - 2pi) - prevangle).abs < (angle - prevangle).abs
    } {
      angle = angle - 2pi;
    };
    while {
      ((angle + 2pi) - prevangle).abs < (angle - prevangle).abs;
    } {
      angle = angle + 2pi;
    };
    angle;
  },

  update_facing_angle: { |e, angle|
    if (e.model.notNil) {
      e.model.facing_angle = angle;
      e.redraw_facing_angle;
    };
  },

  redraw_source: { |e, id|
    var coord = e.postocoord(Polar(
      e.model.source_map[id].distance,
      e.model.source_map[id].azimuth
    ).asPoint);
    e.model.paraspace.setNodeLoc1_(id+2, coord.x, coord.y);
    // node temp
    e.model.paraspace.paraNodes[id+2].temp = coord;
  },

  update_source_azimuth: { |e, id, azimuth|
    if (e.model.notNil) {
      e.model.source_map[id].azimuth = azimuth;
    }
  },
  update_source_distance: { |e, id, distance|
    if (e.model.notNil) {
      e.model.source_map[id].distance = distance;
      e.redraw_source(id);
    }
  },

  build_source_map: { |e|
    e.model.source_map.do { |src_info, i|
      e.model.paraspace.deleteNode(2);
      src_info.rout.stop;
    };
    e.model.source_map = [];
    e.model.panner.src_ids.do { |src_id, i|
      var src_info = (name: e.model.panner.name(src_id), src_id: src_id);
      e.model.paraspace.createNode(0.3, 0.3, e.model.colors.src)
      .setNodeString_(i+2, src_info.name)
      .setNodeSize_(i+2, 15);
      e.model.paraspace.paraNodes[i+2].spritenum = i+2;
      src_info.distance = 0;
      src_info.azimuth = 0;
      src_info.rout = fork {
        loop {
          e.model.panner.get_azimuth(src_id, { |val| e.update_source_azimuth(i, val) });
          e.model.panner.get_distance(src_id, { |val| e.update_source_distance(i, val) });
          0.05.wait;
        }
      };
      e.model.source_map = e.model.source_map.add(src_info);
    }
  },

  draw_paraspace_bg: { |e|
    var pixelspermeter = e.model.width / e.model.metersacross;

    // Major grid lines
    Pen.strokeColor = e.model.colors.grid;
    (e.model.metersacross * sqrt(2)).floor.do { |i|
      var radius = (i + 1) * pixelspermeter;
      Pen.addOval(Rect(
        e.model.centerpoint.x - radius,
        e.model.centerpoint.y - radius,
        radius*2,
        radius*2
      ));
      Pen.stringAtPoint(
        (i + 1).asString,
        (e.model.centerpoint.x + radius + 2)@(e.model.centerpoint.y),
        e.model.fonts.meternumber,
        e.model.colors.meternumber
      );
    };
    Pen.stroke;

    // Meter numbers
    Pen.stringAtPoint(
      "meters",
      (e.model.centerpoint.x + pixelspermeter + 2)@(e.model.centerpoint.y + 10),
      e.model.fonts.meternumber,
      e.model.colors.meternumber
    );

    // Minor grid lines (1/2 meter)
    if (pixelspermeter > 30) {
      Pen.strokeColor = e.model.colors.gridminor;
      (e.model.metersacross * sqrt(2)).floor.do { |i|
        var radius = (i + 0.5) * pixelspermeter;
        Pen.addOval(Rect(
          e.model.centerpoint.x - radius,
          e.model.centerpoint.y - radius,
          radius*2, radius*2
        ));
      };
      Pen.stroke;
    };
  },

  draw_title: { |e|
    // Top of window title/byline
    StaticText(e.model.window, Rect(e.model.margins.left, 5, e.model.width + e.model.margins.right, 50))
    .string_("Binaural audio panner")
    .font_(e.model.fonts.title);
    StaticText(e.model.window, Rect(e.model.margins.left + 3, 50, e.model.width + e.model.margins.right, 20))
    .string_("© 2015 by Eric Sluyter")
    .font_(e.model.fonts.byline);
  },

  draw_lowerpanel: { |e|
    // Panels for bg color
    View(e.model.window, Rect(
      0,
      e.model.margins.top + e.model.height + 5,
      e.model.margins.left + e.model.width + e.model.margins.right,
      e.model.margins.bottom - 5
    ))
    .backColor_(e.model.colors.bglighter);
    View(e.model.window, Rect(
      e.model.margins.left + e.model.width,
      e.model.margins.top + e.model.height + 5,
      e.model.margins.right,
      e.model.margins.bottom - 5
    ))
    .backColor_(Color.black);
    View(e.model.window, Rect(
      e.model.margins.left + 280,
      e.model.margins.top + e.model.height + 5,
      e.model.width - 280,
      e.model.margins.bottom - 5
    ))
    .backColor_(e.model.colors.bgdarker);

    // Width-related labels
    StaticText(e.model.window, Rect(
      e.model.margins.left + 5,
      e.model.margins.top + e.model.height + 20,
      e.model.width,
      30
    ))
    .string_("View width")
    .font_(e.model.fonts.panelhead);
    StaticText(e.model.window, Rect(
      e.model.margins.left + 80,
      e.model.margins.top + e.model.height + 82,
      45,
      20
    ))
    .font_(e.model.fonts.numboxlabel)
    .string_("meters");

    // Width slider and numbox
    e.model.width_slider = Slider(e.model.window, Rect(
      e.model.margins.left + 5,
      e.model.margins.top + e.model.height + 50,
      e.model.width - 150,
      20
    ))
    .value_(e.model.width_spec.unmap(e.model.metersacross))
    .action_({ |view|
      e.update_metersacross(e.model.width_spec.map(view.value));
    });
    e.model.width_numbox = NumberBox(e.model.window, Rect(
      e.model.margins.left + 5,
      e.model.margins.top + e.model.height + 80,
      70,
      20
    ))
    .value_(e.model.metersacross.round)
    .action_({ |view|
      e.update_metersacross(view.value);
    });

    // Bus-related labels
    StaticText(e.model.window, Rect(
      e.model.margins.left + 300,
      e.model.margins.top + e.model.height + 20,
      e.model.width,
      30
    ))
    .string_("Dry bus")
    .font_(e.model.fonts.buslabel);
    StaticText(e.model.window, Rect(
      e.model.margins.left + 300,
      e.model.margins.top + e.model.height + 65,
      e.model.width,
      30
    ))
    .string_("Verb bus")
    .font_(e.model.fonts.buslabel);

    // Bus numboxes
    e.model.drybus_numbox = NumberBox(e.model.window, Rect(
      e.model.margins.left + 300,
      e.model.margins.top + e.model.height + 45,
      70,
      18
    ))
    .value_(e.model.dry_outbus)
    .action_({ |view|
      view.value = max(view.value, 0);
      e.model.panner.dry_outbus_(view.value);
    });
    e.model.wetbus_numbox = NumberBox(e.model.window, Rect(
      e.model.margins.left + 300,
      e.model.margins.top + e.model.height + 90,
      70,
      18
    ))
    .value_(e.model.verb_outbus)
    .action_({ |view|
      view.value = max(view.value, 0);
      e.model.panner.verb_outbus_(view.value);
    });

    // Save, load, reset buttons
    e.model.save_button = Button(e.model.window, Rect(
      e.model.margins.left + e.model.width + 10,
      e.model.margins.top + e.model.height + e.model.margins.bottom - 110,
      e.model.margins.right - 20,
      25
    ))
    .states_([["Save as..."]])
    .font_(e.model.fonts.buttontext)
    .action_({
      // Do things here
    });
    e.model.load_button = Button(e.model.window, Rect(
      e.model.margins.left + e.model.width + 10,
      e.model.margins.top + e.model.height + e.model.margins.bottom - 75,
      e.model.margins.right - 20,
      25
    ))
    .states_([["Load..."]])
    .font_(e.model.fonts.buttontext)
    .action_({
      // Do things here
    });
    e.model.reset_button = Button(e.model.window, Rect(
      e.model.margins.left + e.model.width + 10,
      e.model.margins.top + e.model.height + e.model.margins.bottom - 40,
      e.model.margins.right - 20,
      25
    ))
    .states_([["Reset"]])
    .font_(e.model.fonts.buttontext)
    .action_({
      // Do things here
    });
  },

  update_metersacross: { |e, metersacross|
    // Updates model variable and performs appropriate updates throughout GUI
    metersacross = e.model.width_spec.constrain(metersacross);
    e.model.metersacross = metersacross;
    e.model.width_slider.value = e.model.width_spec.unmap(metersacross);
    e.model.width_numbox.value = e.model.metersacross.round;
    e.model.paraspace.setNodeSize_(0, e.model.width / e.model.metersacross, false);
    /*
    ~sources.do { |source, idx|
    var newcoord = ~postocoord.value(source.pos);
    ~paraspace.setNodeLoc1_(idx + 2, newcoord.x, newcoord.y, false);
    };*/
    e.model.paraspace.refresh;
  },

  draw_rightpanel: { |e|
    // New, edit, delete buttons
    e.model.new_button = Button(e.model.window, Rect(
      e.model.margins.left + e.model.width + 10,
      e.model.margins.top,
      e.model.margins.right - 20,
      25
    ))
    .states_([["New source", Color.black, e.model.colors.newbutt]])
    .font_(e.model.fonts.buttontext)
    .action_({
      e.editorwin(
        "New source",
        "Source " ++ (e.model.panner.next_id + 65).asAscii,
        e.model.panner.src_default.asCompileString,
        { |name, text|
          e.model.panner.make_src(text.interpret, 0, 2, name);
        }
      );
    });
    e.model.edit_button = Button(e.model.window, Rect(
      e.model.margins.left + e.model.width + 10,
      e.model.margins.top + 35,
      e.model.margins.right - 20,
      25
    ))
    .states_([["Edit source", Color.black, e.model.colors.editbutt]])
    .font_(e.model.fonts.buttontext)
    .action_({
      e.model.paraspace.selNodes.do { |node|
        var src_info = e.model.source_map[node.spritenum - 2];
        e.editorwin(
          "Edit source",
          src_info.name,
          e.model.panner.src(src_info.src_id).asCompileString,
          { |name, text|
            e.model.panner.src_(src_info.src_id, text.interpret);
            e.model.panner.name_(src_info.src_id, name);
          }
        );
      };
    });
    e.model.delete_button = Button(e.model.window, Rect(
      e.model.margins.left + e.model.width + 10,
      e.model.margins.top + 70,
      e.model.margins.right - 20,
      25
    ))
    .states_([["Delete source", Color.black, e.model.colors.delbutt]])
    .font_(e.model.fonts.buttontext)
    .action_({
      var src_ids = e.model.paraspace.selNodes.collect { |node|
        e.model.source_map[node.spritenum - 2].src_id;
      };
      src_ids.do { |src_id|
        e.model.panner.free_src(src_id);
      };
    });

    // Reverb labels
    StaticText(e.model.window, Rect(
      e.model.margins.left + e.model.width + 10,
      e.model.margins.top + 120,
      e.model.margins.right,
      30
    ))
    .string_("Room verb")
    .font_(e.model.fonts.panelhead);
    StaticText(e.model.window, Rect(
      e.model.margins.left + e.model.width + e.model.margins.right - 23,
      e.model.margins.top + 310,
      25,
      18
    ))
    .font_(e.model.fonts.numboxlabel)
    .string_("db");

    // Reverb GUI
    e.model.verb_slider = Slider(e.model.window, Rect(
      e.model.margins.left + e.model.width + (e.model.margins.right / 2 - 10),
      e.model.margins.top + 150,
      20,
      150
    ))
    .value_(e.model.verb_spec.unmap(e.model.verb_amp))
    .action_({ |view|
      e.model.panner.verb_amp_(e.model.verb_spec.map(view.value));
    });
    e.model.verb_numbox = NumberBox(e.model.window, Rect(
      e.model.margins.left + e.model.width + 10,
      e.model.margins.top + 305,
      e.model.margins.right - 35,
      20
    ))
    .value_(e.model.verb_amp.ampdb.round(0.1))
    .action_({ |view|
      view.value = view.value.clip(-inf, 0);
      e.model.panner.verb_amp_(view.value.dbamp);
    });
    e.model.verb_button = Button(e.model.window, Rect(
      e.model.margins.left + e.model.width + 10,
      e.model.margins.top + 335,
      e.model.margins.right - 20,
      25
    ))
    .states_([["Edit verb", Color.black, e.model.colors.verbedit]])
    .font_(Font("Helvetica", 12, false))
    .action_({
      e.namelesseditorwin("Edit room verb", e.model.panner.verb_func.asCompileString, { |text|
        e.model.panner.make_verb(text.interpret);
      }, "Reverb editor", "Enter a function that takes a stereo audio-rate argument and returns a stereo reverb signal.");
    });
    e.model.verb_button = Button(e.model.window, Rect(
      e.model.margins.left + e.model.width + 10,
      e.model.margins.top + 370,
      e.model.margins.right - 20,
      25
    ))
    .states_([["Verb mapping", Color.black, e.model.colors.verbedit]])
    .font_(Font("Helvetica", 12, false))
    .action_({
      e.namelesseditorwin("Edit verb mapping", e.model.panner.verb_sendlevel.asCompileString, { |text|
        e.model.panner.verb_sendlevel_(text.interpret);
      }, "Reverb mapper", "Enter a function that takes a distance input and returns a reverb send level.")
    });
  },

  coordtopos: { |e, point|
    var x = (point.x - 0.5) * e.model.metersacross;
    var y = (point.y -0.5) * e.model.metersacross;
    x@y;
  },
  postocoord: { |e, point|
    var x = 0.5 + (point.x / e.model.metersacross);
    var y = 0.5 + (point.y / e.model.metersacross);
    x@y;
  },

  editorwin: { |e, title = "New source", name = "", curtext = "{\n\tPinkNoise.ar(0.1)\n}", doneFunc = nil, heading = "Sound source editor", description =  "Type any valid NodeProxy source code in the box below."|
    var w = Window(title);
    var tv = TextView(w, Rect(0, 110, w.bounds.width, w.bounds.height - 150))
    .font_(Font('Courier New', 14))
    .tabWidth_(10)
    .palette_(QPalette.dark)
    .string_(curtext);
    var namebox = TextField(w, Rect(90, 80, w.bounds.width - 100, 25))
    .string_(name);
    StaticText(w, Rect(10, 15, w.bounds.width - 20, 30))
    .font_(Font('Helvetica', 30, true))
    .string_(heading);
    StaticText(w, Rect(10, 35, w.bounds.width - 20, 50))
    .font_(Font('Helvetica', 12))
    .string_(description);
    StaticText(w, Rect(10, 70, 80, 50))
    .font_(Font('Helvetica', 12))
    .string_("Source name:");
    Button(w, Rect(0, w.bounds.height - 40, w.bounds.width, 40))
    .states_([["Done!", Color(0, 0.3, 0.1), Color(0.5, 1, 0.6)]])
    .font_(Font('Helvetica', 15, true))
    .action_({ doneFunc.value(namebox.string, tv.string); w.close; });
    w.front.alwaysOnTop_(true);
  },

  namelesseditorwin: { |e, title = "New source", curtext = "{\n\tPinkNoise.ar(0.1)\n}", doneFunc = nil, heading = "Sound source editor", description = "Type any valid NodeProxy source code in the box below."|
    var w = Window(title);
    var tv = TextView(w, Rect(0, 85, w.bounds.width, w.bounds.height - 125))
    .font_(Font('Courier New', 14))
    .tabWidth_(10)
    .palette_(QPalette.dark)
    .string_(curtext);
    StaticText(w, Rect(10, 15, w.bounds.width - 20, 30))
    .font_(Font('Helvetica', 30, true))
    .string_(heading);
    StaticText(w, Rect(10, 35, w.bounds.width - 20, 50))
    .font_(Font('Helvetica', 12))
    .string_(description);
    Button(w, Rect(0, w.bounds.height - 40, w.bounds.width, 40))
    .states_([["Done!", Color(0, 0.3, 0.1), Color(0.5, 1, 0.6)]])
    .font_(Font('Helvetica', 15, true))
    .action_({ doneFunc.value(tv.string); w.close; });
    w.front.alwaysOnTop_(true);
  };
);
)