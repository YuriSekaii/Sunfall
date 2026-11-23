# Dying Light 1 Movement Fluidity, Camera Pitch Distribution & Blending Spec

> Directly extracted from `DW/Data0.pak` via [`tools/re_dl_fluidity.py`](../../tools/re_dl_fluidity.py).

---

## 1. FPP Camera & Spine Pitch Distribution (`data/scripts/playeraimlookparamsfpp.scr`)

Parsed **34** `LookParams` / `AimParams` state blocks:

| State | Kind | Horz `[min, max]` | Vert `[min, max]` | Up Dist / Param | Down Dist / Param | Blend Time |
|---|---|---:|---:|---:|---:|---:|
| `Normal` | `LookParams` | `[-179.0, 179.0]` | `[-89.0, 70.0]` | `1.0 / 1.0` | `0.5 / 1.2` | `0.5s` |
| `NormalDuck` | `LookParams` | `["Normal", -]` | `[-, -]` | `1.0 / 100.0` | `- / -` | `-s` |
| `Normal` | `AimParams` | `[-179.0, 179.0]` | `[-80.0, 70.0]` | `1.0 / 1.0` | `0.5 / 1.2` | `0.5s` |
| `NormalDuck` | `AimParams` | `["Normal", -]` | `[-, -]` | `1.0 / 100.0` | `- / -` | `-s` |
| `Sprint` | `LookParams` | `[-179.0, 179.0]` | `[-89.0, 70.0]` | `1.0 / 1.0` | `0.5 / 1.2` | `0.5s` |
| `Sprint` | `AimParams` | `[-179.0, 179.0]` | `[-80.0, 70.0]` | `1.0 / 1.0` | `0.5 / 1.2` | `0.5s` |
| `Jump` | `LookParams` | `[-, -]` | `[-, -]` | `0.0 / 10.0` | `0.0 / 10.0` | `0.0s` |
| `Jump` | `AimParams` | `[-, -]` | `[-, -]` | `- / -` | `- / -` | `0.5s` |
| `WholeBody` | `LookParams` | `[-, -]` | `[-, -]` | `- / -` | `- / -` | `0.5s` |
| `WholeBody` | `AimParams` | `[-, -]` | `[-, -]` | `- / -` | `- / -` | `0.5s` |
| `HeadOnly` | `LookParams` | `[-179.0, 179.0]` | `[-89.0, 70.0]` | `0.2 / 1.0` | `0.2 / 1.0` | `0.3s` |
| `HeadOnly` | `AimParams` | `[-, -]` | `[-, -]` | `- / -` | `- / -` | `0.3s` |
| `NormalOculus` | `LookParams` | `[-179.0, 179.0]` | `[-79.0, 89.0]` | `0.0 / 0.0` | `1.0 / 0.0` | `0.5s` |
| `NormalOculus` | `AimParams` | `[-179.0, 179.0]` | `[-80.0, 70.0]` | `1.0 / 1.0` | `0.5 / 1.2` | `0.5s` |
| `Shield` | `LookParams` | `["Normal", -]` | `[-, -]` | `- / -` | `- / -` | `-s` |
| `Shield` | `AimParams` | `["Normal", -]` | `[-, -]` | `- / -` | `- / -` | `-s` |
| `Firearm` | `LookParams` | `["Normal", -]` | `[-, -]` | `- / -` | `- / -` | `-s` |
| `Firearm` | `AimParams` | `["Normal", -]` | `[-, -]` | `- / -` | `- / -` | `-s` |
| `FirearmReload` | `LookParams` | `["Normal", -]` | `[-, -]` | `- / -` | `- / -` | `-s` |
| `FirearmReload` | `AimParams` | `["Normal", -]` | `[-, -]` | `- / -` | `- / -` | `-s` |
| `MeleeVerticalAttack` | `LookParams` | `["Normal", -]` | `[-, -]` | `- / -` | `- / -` | `-s` |
| `MeleeVerticalAttack` | `AimParams` | `["Normal", -]` | `[-, -]` | `- / -` | `- / -` | `-s` |
| `MeleeAttack` | `LookParams` | `["Normal", -]` | `[-, -]` | `- / -` | `- / -` | `-s` |
| `MeleeAttack` | `AimParams` | `["Normal", -]` | `[-, -]` | `- / -` | `- / -` | `-s` |
| `VehicleDriver` | `LookParams` | `["HeadOnly", -]` | `[-, -]` | `- / -` | `- / -` | `-s` |
| `VehicleDriver` | `AimParams` | `["HeadOnly", -]` | `[-, -]` | `- / -` | `- / -` | `-s` |
| `VehicleUnarmed` | `LookParams` | `[-179.0, 179.0]` | `[-89.0, 70.0]` | `0.2 / 1.0` | `0.4 / 1.0` | `0.3s` |
| `VehicleUnarmed` | `AimParams` | `[-179.0, 179.0]` | `[-70.0, 70.0]` | `0.2 / 1.0` | `0.4 / 1.0` | `0.3s` |
| `VehicleArmed` | `LookParams` | `["Normal", -]` | `[-, -]` | `- / -` | `- / -` | `-s` |
| `VehicleArmed` | `AimParams` | `["Normal", -]` | `[-, -]` | `- / -` | `- / -` | `-s` |
| `PVPGrab` | `LookParams` | `[0.0, 0.0]` | `[0.0, 0.0]` | `1.0 / 1.0` | `0.5 / 1.2` | `0.5s` |
| `PVPGrab` | `AimParams` | `[0.0, 0.0]` | `[0.0, 0.0]` | `1.0 / 1.0` | `0.5 / 1.2` | `0.5s` |
| `Selfie` | `LookParams` | `["Normal", -]` | `[-, -]` | `- / -` | `- / -` | `-s` |
| `Selfie` | `AimParams` | `["Normal", -]` | `[-, -]` | `- / -` | `- / -` | `-s` |

**Why Dying Light never clips the chest when looking down (`-89°`), yet raises arms when looking up (`+70°`):**
- `distribution_vert_up_commited(1.0)` with `param(1.0)` commits `100%` of upward pitch to the spine/upper-body look chain (`_PATH_LOOK_AT`).
- `distribution_vert_down_commited(0.5)` with `param(1.2)` commits only `50%` (non-linear `1.2` power) downward, keeping the chest out of the camera near plane while revealing legs/feet.

---

## 2. FPP Body Look & Aim Bone Chains (`data/vis/playerfppbodyvis.scr`)

```text
RotationController(_PATH_LOOK_AT)
	{
		SetVertRotationAxis([1.0,0.0,0.0]);
		SetHorzRotationAxis([0.0,1.0,0.0]);

		//AddBoneToPath (_BONE_PELVIS);
		AddBoneToPath (_BONE_SPINE_0, false);
		AddBoneToPath (_BONE_SPINE_1, false);
        AddBoneToPath (_BONE_SPINE_2, false);
        AddBoneToPath (_BONE_SPINE_3, false);
		AddBoneToPath (_BONE_EYE_CAMERA, true);
		//AddBoneToPath (_BONE_HEAD);
	}

RotationController(_PATH_LEFT_AIM_AT)
	{
		SetVertRotationAxis([1.0,0.0,0.0]);
		SetHorzRotationAxis([0.0,1.0,0.0]);

		//AddBoneToPath (_BONE_PELVIS);
		AddBoneToPath (_BONE_SPINE_0, false);
		AddBoneToPath (_BONE_SPINE_1, false);
        AddBoneToPath (_BONE_SPINE_2, false);
        AddBoneToPath (_BONE_SPINE_3, false);
		AddBoneToPath (_BONE_L_CLAVICLE, true);
		//AddBoneToPath (_BONE_L_UPPERARM);
	}

RotationController(_PATH_RIGHT_AIM_AT)
	{
		SetVertRotationAxis([1.0,0.0,0.0]);
		SetHorzRotationAxis([0.0,1.0,0.0]);

		//AddBoneToPath (_BONE_PELVIS);
		AddBoneToPath (_BONE_SPINE_0, false);
		AddBoneToPath (_BONE_SPINE_1, false);
        AddBoneToPath (_BONE_SPINE_2, false);
        AddBoneToPath (_BONE_SPINE_3, false);
		AddBoneToPath (_BONE_R_CLAVICLE, true);
		//AddBoneToPath (_BONE_R_UPPERARM);
	}

```

---

## 3. Parkour / Melee Blend Times & Early-Exit Chaining (`m_fpp_*.scr`)

Dying Light's signature fluidity comes from **0.00s–0.10s blend-ins** on vaults/climbs/landings paired with early `CAN_WALK` / `ENABLE_DUCK` / `JUMP_PUSH_OFF` release events before the animation reaches its end frame:

| Script | Track | Dur | Blend | Early Release / Chain Events |
|---|---|---:|---:|---|
| `m_fpp_nm_climb.scr` | `FPP_Unarmed_RoofJump2_FromBottomNoHang_Begin` | `0.25s` | `1.0s` | `—` |
| `m_fpp_nm_climb.scr` | `FPP_Unarmed_RoofJump2_FromBottomNoHang` | `0.725s` | `1.0s` | `18.5, ENABLE_DUCK, -1; 19, CLIMBING_LENGTH, -1` |
| `m_fpp_nm_climb.scr` | `FPP_Unarmed_RoofJump2_FromBottomNoHang1_Begin` | `0.25s` | `1.0s` | `—` |
| `m_fpp_nm_climb.scr` | `FPP_Unarmed_RoofJump2_FromBottomNoHang1` | `0.725s` | `1.0s` | `18.5, ENABLE_DUCK, -1; 19, CLIMBING_LENGTH, -1` |
| `m_fpp_nm_climb.scr` | `FPP_Unarmed_RoofJump2_FromBottomNoHang2_Begin` | `0.25s` | `1.0s` | `—` |
| `m_fpp_nm_climb.scr` | `FPP_Unarmed_RoofJump2_FromBottomNoHang2` | `0.725s` | `1.0s` | `18.5, ENABLE_DUCK, -1; 19, CLIMBING_LENGTH, -1` |
| `m_fpp_nm_jump.scr` | `FPP_Unarmed_Jump_Begin` | `0.667s` | `1.0s` | `0, EVENT_JUMP, -1` |
| `m_fpp_nm_jump.scr` | `FPP_Unarmed_Jump_Begin_1` | `0.667s` | `1.0s` | `0, EVENT_JUMP, -1` |
| `m_fpp_nm_jump.scr` | `FPP_Unarmed_Jump_Begin_InMove` | `1.0s` | `1.0s` | `0, EVENT_JUMP, -1` |
| `m_fpp_nm_jump.scr` | `FPP_Unarmed_Jump_Begin_InMove_Mirror` | `1.0s` | `1.0s` | `0, EVENT_JUMP, -1` |
| `m_fpp_nm_jump.scr` | `FPP_Unarmed_Jump_Begin_InMove_1` | `1.0s` | `1.0s` | `0, EVENT_JUMP, -1` |
| `m_fpp_nm_jump.scr` | `FPP_Unarmed_Jump_Begin_InMove_Mirror_1` | `1.0s` | `1.0s` | `0, EVENT_JUMP, -1` |
| `m_fpp_nm_jump.scr` | `FPP_Stick2Heavy_Jump_Begin` | `0.5s` | `1.0s` | `0, EVENT_JUMP, -1` |
| `m_fpp_nm_jump.scr` | `FPP_Stick2Heavy_Jump_Begin_1` | `0.5s` | `1.0s` | `0, EVENT_JUMP, -1` |
| `m_fpp_nm_jump.scr` | `FPP_Unarmed_JumpOverLow` | `1.167s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_Unarmed_JumpOverLow_1` | `1.167s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_Crossbow_JumpOverLow` | `1.7s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_Crossbow_JumpOverLow_1` | `1.7s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_Stick2Heavy_JumpOverLow` | `1.167s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_Stick2Heavy_JumpOverLow_1` | `1.167s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_Bow_JumpOverLow` | `1.167s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_Bow_JumpOverLow_1` | `1.167s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_Unarmed_JumpOnLowStand` | `0.5s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_Unarmed_JumpOnLowStand_1` | `0.5s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_Unarmed_JumpOnLowStand_2` | `0.5s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_M16_JumpOnLowStand` | `0.5s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_M16_JumpOnLowStand_1` | `0.5s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_M16_JumpOnLowStand_2` | `0.5s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_Stick2Heavy_JumpOnLowStand` | `0.5s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_Stick2Heavy_JumpOnLowStand_1` | `0.5s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_Stick2Heavy_JumpOnLowStand_2` | `0.5s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_Bow_JumpOnLowStand` | `0.5s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_Bow_JumpOnLowStand_1` | `0.5s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_Bow_JumpOnLowStand_2` | `0.5s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_Shotgun_PA_JumpOnLowStand` | `0.5s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_Shotgun_PA_JumpOnLowStand_1` | `0.5s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_Shotgun_PA_JumpOnLowStand_2` | `0.5s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_Unarmed_BeginWallRunLeft` | `0.167s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_Unarmed_WallRunLeft` | `0.4s` | `1.0s` | `2, JUMP_PUSH_OFF, -1` |
| `m_fpp_nm_jump.scr` | `FPP_Unarmed_WallRunFront` | `0.867s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_Unarmed_DodgeLeft` | `0.75s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_Stick2Heavy_DodgeLeft` | `0.667s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_M16_DodgeLeft` | `0.667s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_Bow_DodgeLeft` | `0.667s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_Shotgun_PA_DodgeLeft` | `0.667s` | `1.0s` | `—` |
| `m_fpp_nm_jump.scr` | `FPP_Chainsaw_DodgeLeft` | `0.667s` | `1.0s` | `—` |
| `m_fpp_nm_land.scr` | `FPP_Unarmed_DamperTrashLand` | `1.567s` | `1.0s` | `—` |
| `m_fpp_nm_land.scr` | `FPP_Unarmed_DamperUmbrellaLand` | `1.567s` | `1.0s` | `—` |
| `m_fpp_nm_land.scr` | `FPP_Unarmed_DamperTrashLandBeforeFall` | `0.1s` | `1.0s` | `—` |
| `m_fpp_legs.scr` | `FPP_Unarmed_KickWrestlingStandUpFast` | `1.267s` | `1.0s` | `—` |

---

## 4. Camera Motion Blur, Screen Shake & Zombie Hit FX (`Data0.pak`)

### `varlist_blur_camera_motion.scr` & `varlist_screen_shake.scr`
```text
VarFloat("f_blur_camera_motion_factor", 0.0)
VarFloat("f_blur_camera_motion_near", 0.0)
VarFloat("f_blur_camera_motion_far", 1.0)
VarFloat("f_blur_camera_motion_max", 1.0)
---
VarFloat("f_aberration_scale", 0.0)
VarFloat("f_aberration_speed", 0.0)
VarFloat("f_aberration_strength", 0.0)
VarFloat("f_shake_scale", 0.0)
VarFloat("f_shake_speed", 0.0)
VarFloat("f_shake_strength", 0.0)
```

### `customcollisionsfx/zombie_body.scr` & `zombie_head.scr` (excerpt)
```text
///////////////////////////////////////////////////////////////////////////////////////////////////
// custom collision sfx preset
// http://wiki.techland.pl/chromeengine/bin/view/ChromeEngine4/CollisionSfx
///////////////////////////////////////////////////////////////////////////////////////////////////

import "surface_id.def"

///////////////////////////////////////////////////////////////////////////////////////////////////
sub Sounds()
{
    Hit()
    {
        MinInterval(0.4, 0.8);
        MinSpeed(1.5, 3);
        
        SoundHarder(SurfaceId_Sand, "body_zombie_collision_ground_light_XX.wav", "body_zombie_collision_ground_heavy_XX.wav");
    }
}
---
///////////////////////////////////////////////////////////////////////////////////////////////////
// custom collision sfx preset
// http://wiki.techland.pl/chromeengine/bin/view/ChromeEngine4/CollisionSfx
///////////////////////////////////////////////////////////////////////////////////////////////////

import "surface_id.def"

///////////////////////////////////////////////////////////////////////////////////////////////////
sub Sounds()
{
    Hit()
    {
        MinInterval(0.8);
        MinSpeed(1.5);
        
        SoundHarder(SurfaceId_Sand, "head_collision_ground_XX.wav");
    }
}
```
