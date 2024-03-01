extends Node3D

signal Weapon_Changed
signal Update_Ammo
signal Update_Weapon_Stack

@onready var Animation_Player = get_node("%AnimationPlayer")
@onready var Bullet_Point = get_node("%Bullet_Point")

var Current_Weapon = null
var Weapon_Stack = [] #Array of all currently available weapons
# var Weapon_Indicator = 0
var Next_Weapon: String
var Weapon_List = {}
var Debug_Bullet = preload("res://bullet_debug.tscn")

@export var _weapon_resources: Array[Weapon_Resource]
@export var Start_Weapons: Array[String]

enum {NULL, HITSCAN, PROJECTILE}

var Collision_Exclusion = []

func _ready():
	Initialize(Start_Weapons) #Enter the State Machine

func _input(event):
	if event.is_action_released("Weapon_Up"):
		var getref = Weapon_Stack.find(Current_Weapon.Weapon_Name)
		getref = min(getref+1, Weapon_Stack.size()-1)
		exit(Weapon_Stack[getref])

	if event.is_action_released("Weapon_Down"):
		var getref = Weapon_Stack.find(Current_Weapon.Weapon_Name)
		getref = max(getref-1, 0)
		exit(Weapon_Stack[getref])

	if event.is_action_pressed("Primary Fire"):
		shoot()

	if event.is_action_pressed("Reload"):
		reload()

	if event.is_action_pressed("Drop"):
		Drop(Current_Weapon.Weapon_Name)

func Initialize(_start_weapons: Array):
	#create a dictionary to refer to our weapons
	for weapon in _weapon_resources:
		Weapon_List[weapon.Weapon_Name] = weapon
	
	for i in _start_weapons:
		Weapon_Stack.push_back(i) #add our starting weapons
	
	Current_Weapon = Weapon_List[Weapon_Stack[0]]
	emit_signal("Update_Weapon_Stack", Weapon_Stack)
	enter()

func enter():
	Animation_Player.queue(Current_Weapon.Activate_Anim) #call when first "entering" a weapon
	emit_signal("Weapon_Changed", Current_Weapon.Weapon_Name)
	emit_signal("Update_Ammo", [Current_Weapon.Current_Ammo, Current_Weapon.Reserve_Ammo])

func exit(_next_weapon: String):
	#in order to change weapons, first call exit
	if _next_weapon != Current_Weapon.Weapon_Name:
		if Animation_Player.get_current_animation() != Current_Weapon.Deactivate_Anim:
			Animation_Player.play(Current_Weapon.Deactivate_Anim)
			Next_Weapon = _next_weapon

func Change_Weapon(Weapon_Name: String):
	Current_Weapon = Weapon_List[Weapon_Name]
	Next_Weapon = ""
	enter()

func _on_animation_player_animation_finished(anim_name):
	if anim_name == Current_Weapon.Deactivate_Anim:
		Change_Weapon(Next_Weapon)

	if anim_name == Current_Weapon.Shoot_Anim && Current_Weapon.Auto_Fire == true:
		if Input.is_action_pressed("Primary Fire"):
			shoot()

func shoot():
	if Current_Weapon.Current_Ammo != 0:
		if !Animation_Player.is_playing(): #enforces the fire rate set by the animation
			Animation_Player.play(Current_Weapon.Shoot_Anim)
			Current_Weapon.Current_Ammo -= 1
			emit_signal("Update_Ammo", [Current_Weapon.Current_Ammo, Current_Weapon.Reserve_Ammo])
			var camera_collision = get_camera_collision()
			match Current_Weapon.Type:
				NULL:
					print("Weapon Type Not Chosen!")
				HITSCAN:
					hitscan_collision(camera_collision)
				PROJECTILE:
					Launch_Projectile(camera_collision)
	else:
		reload()

func reload():
	if Current_Weapon.Current_Ammo == Current_Weapon.Magazine:
		return
	elif !Animation_Player.is_playing():
		if Current_Weapon.Reserve_Ammo != 0:
			Animation_Player.play(Current_Weapon.Reload_Anim)
			var Reload_Amount = min(Current_Weapon.Magazine - Current_Weapon.Current_Ammo, Current_Weapon.Magazine, Current_Weapon.Reserve_Ammo)
			
			Current_Weapon.Current_Ammo = Current_Weapon.Current_Ammo + Reload_Amount
			Current_Weapon.Reserve_Ammo = Current_Weapon.Reserve_Ammo - Reload_Amount
			
			emit_signal("Update_Ammo", [Current_Weapon.Current_Ammo, Current_Weapon.Reserve_Ammo])
		else:
			Animation_Player.play(Current_Weapon.OOA_Anim)


func get_camera_collision()->Vector3:
	var camera = get_viewport().get_camera_3d()
	var viewport = get_window().get_content_scale_size()
	
	var Ray_Origin = camera.project_ray_origin(viewport/2)
	var Ray_End = Ray_Origin + camera.project_ray_normal(viewport/2)*Current_Weapon.Weapon_Range
	
	var New_Intersection = PhysicsRayQueryParameters3D.create(Ray_Origin, Ray_End)
	New_Intersection.set_exclude(Collision_Exclusion)
	var Intersection = get_world_3d().direct_space_state.intersect_ray(New_Intersection)
	
	if not Intersection.is_empty():
		var Collision_Point = Intersection.position
		return Collision_Point
	else:
		return Ray_End
	

func hitscan_collision(Collision_Point):
	var Bullet_Direction = (Collision_Point - Bullet_Point.get_global_transform().origin).normalized()
	var New_Intersection = PhysicsRayQueryParameters3D.create(Bullet_Point.get_global_transform().origin,Collision_Point+Bullet_Direction*2)
	var Bullet_Collision = get_world_3d().direct_space_state.intersect_ray(New_Intersection)
	
	if Bullet_Collision:
		var hit_indicator = Debug_Bullet.instantiate()
		var world = get_tree().get_root().get_child(0)
		world.add_child(hit_indicator)
		hit_indicator.global_translate(Bullet_Collision.position)
		hitscan_damage(Bullet_Collision.collider, Bullet_Direction, Bullet_Collision.position)

func hitscan_damage(Collider, Direction, Position):
	if Collider.is_in_group("Target") and Collider.has_method("Hit_Successful"):
		Collider.Hit_Successful(Current_Weapon.Damage, Direction, Position)

func Launch_Projectile(Point: Vector3):
	var Direction = (Point - Bullet_Point.get_global_transform().origin).normalized()
	var Projectile = Current_Weapon.Projectile_To_Load.instantiate()
	
	var Projectile_RID = Projectile.get_rid()
	Collision_Exclusion.push_front(Projectile_RID)
	Projectile.tree_exited.connect(Remove_Exclusion.bind(Projectile.get_rid()))
	
	Bullet_Point.add_child(Projectile)
	Projectile.Damage = Current_Weapon.Damage
	Projectile.set_linear_velocity(Direction*Current_Weapon.Projectile_Velocity)

func Remove_Exclusion(Projectile_RID):
	Collision_Exclusion.erase(Projectile_RID)


func _on_pick_up_detection_body_entered(body):
	print(body.Pick_Up_Type)
	if body.Pick_Up_Ready:
		var Weapon_In_Stack = Weapon_Stack.find(body.weapon_name,0)
		
		if Weapon_In_Stack == -1 && body.Pick_Up_Type == "Weapon":
			var getref = Weapon_Stack.find(Current_Weapon.Weapon_Name)
			Weapon_Stack.insert(getref,body.weapon_name)
			#zero out ammo in resource
			Weapon_List[body.weapon_name].Current_Ammo = body.current_ammo
			Weapon_List[body.weapon_name].Reserve_Ammo = body.reserve_ammo
			
			emit_signal("Update_Weapon_Stack", Weapon_Stack)
			exit(body.weapon_name)
			body.queue_free()
		else:
			var remaining = Add_Ammo(body.weapon_name, body.current_ammo + body.reserve_ammo)
			
			if remaining == 0:
				body.queue_free()
			
			body.current_ammo = min(remaining, Weapon_List[body.weapon_name].Magazine)
			body.reserve_ammo = max(remaining - body.current_ammo, 0)

func Drop(_name:String):
	if Weapon_List[_name].Can_Be_Dropped && Weapon_Stack.size() != 1:
		var Weapon_Ref = Weapon_Stack.find(_name,0)
		
		if Weapon_Ref != -1:
			Weapon_Stack.pop_at(Weapon_Ref)
			emit_signal("Update_Weapon_Stack", Weapon_Stack)
			
			var Weapon_Dropped = Weapon_List[_name].Weapon_Drop.instantiate()
			Weapon_Dropped.current_ammo = Weapon_List[_name].Current_Ammo
			Weapon_Dropped.reserve_ammo = Weapon_List[_name].Reserve_Ammo
			
			Weapon_Dropped.set_global_transform(Bullet_Point.get_global_transform())
			var World = get_tree().get_root().get_child(0)
			World.add_child(Weapon_Dropped)
			
			var getref = Weapon_Stack.find(Current_Weapon.Weapon_Name)
			getref = max(getref-1,0)
			exit(Weapon_Stack[0])

func Add_Ammo(_Weapon: String, Ammo: int)-> int:
	var _weapon = Weapon_List[_Weapon]
	
	var Required = _weapon.Max_Ammo - _weapon.Reserve_Ammo
	var Remaining = max(Ammo - Required, 0)
	
	_weapon.Reserve_Ammo += min(Ammo, Required)
	emit_signal("Update_Ammo", [Current_Weapon.Current_Ammo, Current_Weapon.Reserve_Ammo])
	return Remaining
