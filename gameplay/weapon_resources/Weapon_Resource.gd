extends Resource

class_name Weapon_Resource

@export var Weapon_Name: String
@export var Activate_Anim: String
@export var Shoot_Anim: String
@export var Reload_Anim: String
@export var Deactivate_Anim: String
@export var OOA_Anim: String

@export var Current_Ammo: int
@export var Reserve_Ammo: int
@export var Magazine: int
@export var Max_Ammo: int

@export var Auto_Fire: bool
@export var Weapon_Range: int
@export var Damage: int
@export_flags("Hitscan","Projectile") var Type
@export var Projectile_To_Load: PackedScene
@export var Projectile_Velocity: int

@export var Weapon_Drop: PackedScene
@export var Can_Be_Dropped: bool
