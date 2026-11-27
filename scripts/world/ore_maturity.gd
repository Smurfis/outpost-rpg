extends RefCounted
## Ore deposit maturity, independent of gear rarity and gathering skill.
## Prototype tuning: harvest again after 30 seconds, gain one star every
## 90 seconds thereafter. Full maturity after six minutes, 30 seconds.
const RECOVERY := 30.0
const STAR_INTERVAL := 90.0
const MAX_AGE := RECOVERY+4.0*STAR_INTERVAL

static func stars(age: float) -> int:
	if age<RECOVERY: return 0
	return clampi(1+floori((age-RECOVERY)/STAR_INTERVAL),1,5)

static func age(last_break: float,now: float) -> float:
	if last_break<=0.0: return MAX_AGE
	return clampf(now-last_break,0.0,MAX_AGE)

static func rarity_chances(maturity: int) -> Array[float]:
	# Move bounded probability from common into higher ranks. Never guarantee
	# a rare item. Experimental curve; no live inventory provenance yet.
	var boost := float(clampi(maturity,1,5)-1)/4.0
	return [0.60-0.20*boost,0.27+0.08*boost,0.10+0.07*boost,0.025+0.035*boost,0.005+0.015*boost]
