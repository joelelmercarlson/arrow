{-# LANGUAGE OverloadedStrings #-}
{-

Game.Combat.hs

P vs. M
  0. Check Weapon WT (WWT) and Weight (WT) for Encumbered and Finesse...
     a. if WWT and/or WT is Heavy/Encumbered lose Proficiency
     b. Shooters and Casters must use light weapons (<5 lbs)...
  1. Roll AR on D20
  2. if pAR >= mAC then pDam else Miss
     a. Melee: pDam is Weapon + pStr
     b. Throw: pDam is Weapon + pDex
     c. Cast:  pDam is Weapon + pInt
  3. mHP is recorded
  4. updateWorld with misfires, Deaths and Corpses...

Author: "Joel E Carlson" <joel.elmer.carlson@gmail.com>

-}
module Game.Combat (mkCombat
                   , mkMagicCombat
                   , mkRangeCombat) where

import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T
import Engine.Arrow.Data (World (..))
import qualified Game.DiceSet as DS
import qualified Game.Entity as GE
import qualified Game.Inventory as GI
import qualified Game.Journal as GJ
import qualified Game.Player as GP
import Game.Kind.Entity
import Game.Rules

-- types for clarity...
type Seed = Int
type Attacks = Int
type Name = Text
type Weapon = Text
type AC = Int
type AR = Int
type HP = Int
type EXP = Int

-- | attackAction
-- handle many attacks
attackAction :: Seed
  -> Name
  -> Attacks
  -> Weapon
  -> Int
  -> Int
  -> Name
  -> AC
  -> ([Text], Int)
attackAction pSeed pName pAtk pWeap pStat pEnc mName mDR = let
    pD20  = take pAtk $ DS.rollList 11 20 (pSeed+1)
    pHits = [ (pHit, pDam) | r <- pD20, let
                  pAR = criticalRoll r pStat pEnc
                  pDam = if pAR >= mDR
                    then criticalDamage pAR pWeap (pSeed+r) pStat
                    else 0
                  hit    = attack pAR mDR mName
                  result = abilityResult pDam pAR pStat pEnc
                  pHit   = T.concat [ pName, hit, result, "." ] ]
    pDamage = sum $ [ v | (_,v) <- pHits ]
    pEntry  = [ k | (k,_) <- pHits ]
  in (pEntry, pDamage)

-- | attack verb
attack :: AR -> AC -> Name -> Text
attack ar ac name
  | ar == 1   = T.append " ~fumbles~ attack at " name
  | ar == 100 = T.append " Critical hits the " name
  | ar >= ac  = T.append " hits the " name
  | otherwise = T.append " attack misses " name

-- | condition of Monster
condition :: HP -> EXP -> Text
condition hp xp
  | hp < 1  = T.concat [ " Dead!"
                       , T.pack $ " You gain " ++ show xp ++ " experience." ]
  | hp < 6  = " *Critical*."
  | hp < 10 = " Hurt."
  | otherwise = " Ok."

-- | death
-- Inventory drop around the Corpse...
death :: Int -> EntityKind -> AssetMap -> EntityMap -> EntityMap
death mx mEntity am em = let
  mPos   = coord mEntity
  mInv   = inventory mEntity
  mArrow = Map.findWithDefault 0 "Arrow"    mInv
  mItem  = Map.findWithDefault 0 "Item"     mInv
  mMush  = Map.findWithDefault 0 "Mushroom" mInv
  mPot   = Map.findWithDefault 0 "Potion"   mInv
  loc    = scatter mEntity
  -- Item mostly Coin
  item
    | mItem   > 0 = GI.mkRandItem loc am
    | mPot    > 0 = GI.mkDropItem "Potion"   loc am
    | mMush   > 0 = GI.mkDropItem "Mushroom" loc am
    | mArrow  > 0 = GI.mkDropItem "Arrow"    loc am
    | otherwise   = GI.mkDropItem "Coin"     loc am
  corpse = GI.mkDropItem "Corpse" mPos am
  newCorpse = GE.updateEntity mx corpse em
  in GI.putDown item newCorpse

-- | misFire
-- Arrows that miss the mark...
misFire :: EntityKind -> AssetMap -> EntityMap -> EntityMap
misFire mEntity am em = let
  loc  = scatter mEntity
  item = GI.mkDropItem "Arrow" loc am
  in GI.putDown item em

-- | mkCombat
-- Melee...
mkCombat :: Int -> Int -> World -> World
mkCombat px mx w = if px == mx
  then w
  else let
    (pEntity, pPos) = GE.getEntityAt px (entityT w)
    (mEntity, _)    = GE.getEntityAt mx (entityT w)
    -- random seed
    pSeed = tick w + uncurry (*) pPos :: Int
    -- pAR, pDam, pMod
    pName = propertyLookup "Name" pEntity
    -- COMBAT
    (pStr, pStrMod) = abilityLookup "str" pEntity
    (_, pDexMod) = abilityLookup "dex" pEntity
    pAtk  = propertyNLookup "ATTACKS" pEntity
    pWWT  = propertyNLookup "WWT" pEntity
    pWeap = propertyLookup "ATTACK" pEntity
    -- Fighter or Rogue, Finesse?
    pStat = if pWWT < 3 then pDexMod else pStrMod
    -- Encumbered?
    pWT  = propertyNLookup "WT" pEntity
    pMod = propertyNLookup "Proficiency" pEntity
    pEnc = checkEncumberance pStr pWT pMod
    -- ATTACK roll
    (pEntry, pDamage) = attackAction pSeed pName pAtk pWeap pStat pEnc mName mAC
    pAttack = mHP - pDamage
    -- mAC
    mName = propertyLookup "Name" mEntity
    mAC   = propertyNLookup "AC" mEntity
    mHP   = eHP mEntity
    mExp  = eXP mEntity
    mCond = T.concat [ mName, " is", condition pAttack mExp ]
    -- newEntity with damages and deaths and Exp awards
    newEntity = if pAttack < 1
      then death mx mEntity (assetT w) $ GP.updatePlayerXP mExp (entityT w)
      else GE.updateEntityHp mx pAttack (entityT w)
  in w { entityT  = newEntity
       , journalT = GJ.updateJournal (mCond : pEntry) (journalT w) }

-- | mkMagicCombat
-- Cast, Chant, Magic Combat...
mkMagicCombat :: Int -> Int -> World -> World
mkMagicCombat px mx w = if px == mx
  then w
  else let
    (pEntity, pPos) = GE.getEntityAt px (entityT w)
    (mEntity, _)    = GE.getEntityAt mx (entityT w)
    -- random seed
    pSeed = tick w + uncurry (*) pPos :: Int
    -- pAR, pDam, pMod
    pName = propertyLookup "Name" pEntity
    -- MAGIC
    (pStr, _) = abilityLookup "str" pEntity
    (_, pIntMod) = abilityLookup "int" pEntity
    (_, pWisMod) = abilityLookup "wis" pEntity
    pWWT = propertyNLookup "WWT" pEntity
    pAtk = 1
    -- Mage or Cleric, Finesse?
    pWeap = checkFinesse pWWT $ propertyLookup "CAST" pEntity
    pClass = propertyLookup "Class" pEntity
    pStat = if pClass == "Cleric" then pWisMod else pIntMod
    -- Encumbered?
    pWT  = propertyNLookup "WT" pEntity
    pMod = propertyNLookup "Proficiency" pEntity
    pEnc = checkEncumberance pStr pWT pMod
    -- CAST roll
    (pEntry, pDamage) = attackAction pSeed pName pAtk pWeap pStat pEnc mName mAC
    pAttack = mHP - pDamage
    -- mAC
    mName = propertyLookup "Name" mEntity
    mAC   = propertyNLookup "AC" mEntity
    mHP   = eHP mEntity
    mExp  = eXP mEntity
    mCond = T.concat [ mName, " is", condition pAttack mExp ]
    -- misFire
    shotEntity = if pDamage < 5
      then misFire mEntity (assetT w) (entityT w)
      else entityT w
    -- newEntity with damages and deaths and Exp awards
    newEntity = if pAttack < 1
      then death mx mEntity (assetT w) $ GP.updatePlayerXP mExp (entityT w)
      else GE.updateEntityHp mx pAttack shotEntity
  in w { entityT  = newEntity
       , journalT = GJ.updateJournal (mCond:pEntry) (journalT w) }

-- | mkRangeCombat
-- Shoot, Throw, Ranged Combat...
mkRangeCombat :: Int -> Int -> World -> World
mkRangeCombat px mx w = if px == mx
  then w
  else let
    (pEntity, pPos) = GE.getEntityAt px (entityT w)
    (mEntity, _)    = GE.getEntityAt mx (entityT w)
    -- random seed
    pSeed = tick w + uncurry (*) pPos :: Int
    -- pAR, pDam, pMod
    pName = propertyLookup "Name" pEntity
    -- THROW
    (pStr, _)  = abilityLookup "str" pEntity
    (_, pStat) = abilityLookup "dex" pEntity
    pAtk  = propertyNLookup "ATTACKS" pEntity
    pWWT  = propertyNLookup "WWT" pEntity
    -- Encumbered?
    pWT   = propertyNLookup "WT" pEntity
    pMod  = propertyNLookup "Proficiency" pEntity
    pEnc  = checkEncumberance pStr pWT pMod
    pWeap = checkFinesse pWWT $ propertyLookup "SHOOT" pEntity
    -- SHOOT roll
    (pEntry, pDamage) = attackAction pSeed pName pAtk pWeap pStat pEnc mName mAC
    pAttack = mHP - pDamage
    -- mAC
    mName = propertyLookup "Name" mEntity
    mAC   = propertyNLookup "AC" mEntity
    mHP   = eHP mEntity
    mExp  = eXP mEntity
    mCond = T.concat [ mName, " is", condition pAttack mExp ]
    -- misFire
    shotEntity = if pDamage < 5
      then misFire mEntity (assetT w) (entityT w)
      else entityT w
    -- newEntity with damages and deaths and Exp awards
    newEntity = if pAttack < 1
      then death mx mEntity (assetT w) $ GP.updatePlayerXP mExp (entityT w)
      else GE.updateEntityHp mx pAttack shotEntity
  in w { entityT  = newEntity
       , journalT = GJ.updateJournal (mCond:pEntry) (journalT w) }

-- | nth safe chooser
nth :: Int -> [(Int, Int)] -> (Int, Int)
nth _ []     = (0, 0)
nth 1 (x:_)  = x
nth n (_:xs) = nth (n-1) xs

-- | scatter
scatter :: EntityKind -> (Int, Int)
scatter mEntity = let
  mPos     = coord mEntity
  -- random around the target
  seed     = 1 + uncurry (*) mPos
  missList = moveT mEntity
  missRoll = head $ DS.rollList 1 (fromIntegral $ length missList) seed
  in nth missRoll missList
