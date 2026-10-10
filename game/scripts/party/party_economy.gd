class_name FurPartyEconomy
extends RefCounted

# Tables only; all wallet/property writers remain in PartyModel.
const MAX_ROUNDS:=8
const TEAM_GOAL:=4
const PROPERTY_PRICE:=8
const UPGRADE_PRICE:=6
const WORKSHOP_PRICE:=6
const WORKSHOP_IDS:=["weapon","power","speed","area","crit","link","heal","bounce"]
const ITEM_PRICES:={"boost":5,"shield":4,"swap":7}
const JOINT_LAST_ACCEPT_ROUND:=5
const JOINT_WINDOW_ROUNDS:=3
const JOINT_STAR_DISCOUNT:=5
const JOINT_PARTNER_REWARD:=5
const STAR_MIGRATION_FEE:=2

static func region_bonus(district:int)->Dictionary:
	return {"health":12.0 if district==2 else 0.0,"damage":.12 if district==1 else 0.0,"reward":2 if district==0 else 0}

static func preparation_options(coins:int)->Array[Dictionary]:
	return [{"choice":0,"label":"补给：本场生命 +12（免费）","cost":0,"enabled":true},{"choice":1,"label":"营业合同：押3；胜返7 / 败返1；伤害 +12%","cost":3,"enabled":coins>=3}]

static func item_cost(kind:String,discount:int)->int:
	return maxi(1,int(ITEM_PRICES.get(kind,999))-clampi(discount,0,2))

static func valid_workshop(upgrade_id:Variant)->bool:
	return typeof(upgrade_id)==TYPE_STRING and upgrade_id in WORKSHOP_IDS
