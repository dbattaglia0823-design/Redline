extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g)
 g.set_process(false); g.set_physics_process(false); g.profile=DriverProfile.new(); g.refresh_car(); RosterTest.ready(g); g.start_race()
 DirAccess.make_dir_recursive_absolute("res://validation/race_hud")
 for phone in [false,true]:
  root.size=Vector2i(390,844) if phone else Vector2i(1200,760)
  g.sync_menu_size(); g.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://validation/race_hud/after_"+("phone" if phone else "desktop")+".png")
 g.stop_presentation_audio(); await create_timer(.12).timeout; g.queue_free(); await process_frame; quit()

