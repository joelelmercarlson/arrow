{-# LANGUAGE OverloadedStrings #-}
{-

Game.Player.hs

Game.Player is the Player rules for Equipment, Inventory, etc...

Author: "Joel E Carlson" <joel.elmer.carlson@gmail.com>

-}
module Game.Player (characterEquipment
                   , characterExamine
                   , characterInventory
                   , characterLook
                   , characterSheet
                   , characterStore
                   , characterTarget
                   , getArrow
                   , getHealth
                   , getMana
                   , getMushroom
                   , getPotion
                   , getPlayer
                   , updatePlayerBy
                   , updatePlayer
                   , updatePlayerXP) where

import Prelude hiding (lookup)
import Control.Arrow ((&&&))
import Data.List
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T
import qualified Game.Entity as GE
import Game.Kind.Entity
import Game.Rules

type Coord = (Int, Int)

-- | @ Equipment
-- Actions:
--   (I)nventory mode
--   (W)ield to Doff
characterEquipment :: EntityMap -> AssetMap -> [Text]
characterEquipment em _ = let
  (pEntity, _) = getPlayer em
  pProp = property pEntity
  pInv = [melee, shoot, ring, neck, armor, cloak, shield, helmet, hands, feet]
  melee  = T.append "Melee:  " $ Map.findWithDefault "None" "melee" pProp
  shoot  = T.append "Shoot:  " $ Map.findWithDefault "None" "shoot" pProp
  ring   = T.append "Ring:   " $ Map.findWithDefault "None" "jewelry" pProp
  neck   = T.append "Neck:   " $ Map.findWithDefault "None" "neck" pProp
  armor  = T.append "Armor:  " $ Map.findWithDefault "None" "armor" pProp
  cloak  = T.append "Cloak:  " $ Map.findWithDefault "None" "cloak" pProp
  shield = T.append "Shield: " $ Map.findWithDefault "None" "shield" pProp
  helmet = T.append "Head:   " $ Map.findWithDefault "None" "head" pProp
  hands  = T.append "Hands:  " $ Map.findWithDefault "None" "hands" pProp
  feet   = T.append "Feet:   " $ Map.findWithDefault "None" "feet" pProp
  armorClass = T.append "AC: " $ Map.findWithDefault "0" "AC" pProp
  attack = T.append "Attack: " $ Map.findWithDefault "0" "ATTACK" pProp
  range  = T.append "Shoot:  " $ Map.findWithDefault "0" "SHOOT" pProp
  tags   = T.append "Tags:   " $ Map.findWithDefault "None" "TAGS" pProp
  -- Encumbered, Heavy weapons?
  pWT  = read $ T.unpack $ Map.findWithDefault "0" "WT" pProp :: Int
  pWWT = read $ T.unpack $ Map.findWithDefault "0" "WWT" pProp :: Int
  pEnc = if pWT > 5 * pStr
    then "Load:   ENCUMBERED!"
    else T.concat [ "Load:   "
                  , T.pack $ show pWT, "/"
                  , T.pack $ show (5 * pStr), " lbs." ]
  pHeavy = if pWWT < 3
    then "Weapon: Finesse"
    else T.concat [ "Weapon: ", T.pack $ show pWWT, " lbs." ]
  -- Skills
  (pStr, pStrMod) = abilityLookup "str" pEntity
  (_, pDexMod) = abilityLookup "dex" pEntity
  (_, pConMod) = abilityLookup "con" pEntity
  (_, pIntMod) = abilityLookup "int" pEntity
  (_, pWisMod) = abilityLookup "wis" pEntity
  pSkills = T.concat [ "Ability:"
                     , " Melee:",  resultFmt pStrMod
                     , "/", resultFmt pDexMod
                     , ", Shoot ", resultFmt pDexMod
                     , ", Toughness:", resultFmt pConMod
                     , ", Magic:", resultFmt pIntMod
                     , ", Willpower:", resultFmt pWisMod
                     ]
  in selection pInv
  ++ [ armorClass, attack, range, pEnc, pHeavy, tags, pSkills
     , "Press [0-9] to Doff. (I)nventory. Press ESC to Continue." ]

-- | @ Examine
-- Actions:
--   E(X)amine mode
characterExamine :: [Coord] -> EntityMap -> AssetMap -> [Text]
characterExamine fov em _ = let
  (_, gPos) = getPlayer em
  view = GE.fromEntityBy em
  pFOV = [ loc | (ek, _) <- filter (\(_, j) -> j `elem` fov) view,
           let name = Map.findWithDefault "None" "Name" (property ek)
               loc  = characterLocator name gPos (coord ek) ]
  in selection pFOV
  ++ [ " ", "Press [0-9, A-J] to E(X)amine. ESC to Continue." ]

-- | @ Inventory
-- Actions:
--   (I)nventory to Don
--   (D)rop mode
--   (S)ell in (A)cquire mode
characterInventory :: EntityMap -> AssetMap -> [Text]
characterInventory em _ = let
  (pEntity, _) = getPlayer em
  pItems = filter (\(i, j) -> j > 0 &&
                  i `notElem` ["Arrow", "Coin", "Mushroom", "Potion"]) $
           Map.toList (inventory pEntity)
  pInv = filter (/="None") $
    [ name | (k, v) <- pItems,
      let name = if v > 0
            then T.concat [ k, " (", T.pack $ show v, ")" ]
            else "None" ]
  in selection pInv
  ++ [ " ", "Press [0-9, A-J] to Don. (D)rop/(S)ell/(W)ield. ESC to Continue." ]

-- | @ Locator
-- Track with N/S/E/W
characterLocator :: Text -> Coord -> Coord -> Text
characterLocator name (x1,y1) (x2,y2) = let
  north :: Int -> Text
  north n = if n < 0
    then T.append (T.pack $ show $ abs n) " S"
    else T.append (T.pack $ show n) " N"
  west :: Int -> Text
  west n = if n < 0
    then T.append (T.pack $ show $ abs n) " E"
    else T.append (T.pack $ show n) " W"
  dX = x1 - x2
  dY = y1 - y2
  in T.concat [ name, " (", north dY, ", ", west dX, ")" ]

-- | @ Look
-- What can @ see in FOV...
characterLook :: [Coord] -> EntityMap -> [Text]
characterLook fov em = let
  groupF :: [Text] -> [(Text, Int)]
  groupF = map (head &&& length) . group . sort
  view = GE.fromEntityBy em
  entities = groupF $
    [ name | (ek, _) <- filter (\(_, j) -> j `elem` fov) view,
      let label = Map.findWithDefault "None" "Name" (property ek)
          mHP = eHP ek
          mMaxHP = eMaxHP ek
          status = condition label mHP mMaxHP
          name = if mHP > 0
                 then status
                 else label ]
  pFOV = [ seen | (i, j) <- entities,
           let seen = if j > 1
                 then T.concat [ i," <", T.pack $ show j, ">" ]
                 else i ]
  in selection pFOV

-- | @ Stats
characterSheet :: EntityMap -> [Text]
characterSheet em = let
  (pEntity, _) = getPlayer em
  pInv   = inventory pEntity
  pCoin  = T.append "AU: " (T.pack $ show $ Map.findWithDefault 0 "Coin" pInv)
  pProp  = property pEntity
  pEquip = T.concat [ equip "melee" "|" pProp
    , equip "shoot"   "{" pProp
    , equip "jewelry" "=" pProp
    , equip "neck"    "\"" pProp
    , equip "armor"   "[" pProp
    , equip "cloak"   "(" pProp
    , equip "shield"  ")" pProp
    , equip "head"    "]" pProp
    , equip "hands"   "]" pProp
    , equip "feet"    "]" pProp
    ]
  pCls = Map.findWithDefault "Player" "Class" pProp
  pStr = T.append "Str: " $ Map.findWithDefault "1" "str" pProp
  pDex = T.append "Dex: " $ Map.findWithDefault "1" "dex" pProp
  pCon = T.append "Con: " $ Map.findWithDefault "1" "con" pProp
  pInt = T.append "Int: " $ Map.findWithDefault "1" "int" pProp
  pWis = T.append "Wis: " $ Map.findWithDefault "1" "wis" pProp
  pLvl = T.pack $ "Level: " ++ show (eLvl pEntity)
  pExp = T.pack $ "EXP: " ++ show (eXP pEntity)
  in [ pCls, pLvl, pExp, pCoin, pEquip, pStr, pDex, pCon, pInt, pWis ]

-- | @ Store
-- Actions:
--   Purchase
--   (S)ell mode
characterStore :: EntityMap -> AssetMap -> [Text]
characterStore em am = let
  (pEntity, _) = getPlayer em
  descMap = Map.fromList $
    [ (name, desc) | (_, v) <- Map.toList am,
      let name = Map.findWithDefault "None" "Name" (property v)
          desc = Map.findWithDefault "None" "Description" (property v) ]
  pInv = filter (/="None") $
    [ name | (k, v) <- Map.toList (inventory pEntity),
      let name = if k `elem` ["Arrow", "Mushroom", "Potion"]
            then T.concat [ k, " (", T.pack $ show v, ") ", item ]
            else "None"
          item = Map.findWithDefault "None" k descMap ]
  in selection pInv
  ++ [ " ", "Press [0-9, A-J] to Purchase. (S)ell. ESC to Continue." ]

-- | @ Target
characterTarget :: [Text]
characterTarget = [ "1) NW -  0) N - 7) NE"
                  , "2) W  -  ---- - 6) E"
                  , "3) SW -  4) S - 5) SE"
                  , "Press [0-7] to Target. ESC to Continue."
                  ]

-- | @ condition
-- Green, Red, Purple...
condition :: Text -> Int -> Int -> Text
condition label hp maxHP = let
  status n
    | n < 5 = "*"
    | (maxHP `div` n) > 2 = "!"
    | otherwise = ":"
  in T.concat [ label, " (HP", status hp, " "
              , T.pack $ show hp, "/", T.pack $ show maxHP, ")" ]

-- | @ equipment
equip :: Text -> Text -> Properties -> Text
equip name desc pProp = let
  item = Map.findWithDefault "None" name pProp
  equipped n
    | n == "None" = "."
    | otherwise = desc
  in equipped item

-- | @ Arrow
getArrow :: EntityMap -> Double
getArrow em = let
  (pEntity, _) = getPlayer em
  pArrow = fromIntegral $ Map.findWithDefault 0 "Arrow" (inventory pEntity)
  in pArrow / 20.0

-- | @ Health
getHealth :: EntityMap -> Double
getHealth em = let
  (pEntity, _) = getPlayer em
  hp    = fromIntegral $ eHP pEntity
  maxHp = fromIntegral $ eMaxHP pEntity
  in if maxHp > 0.0 then hp / maxHp else 0.0

-- | @ Mushroom
getMushroom :: EntityMap -> Double
getMushroom em = let
  (pEntity, _) = getPlayer em
  pMush = fromIntegral $ Map.findWithDefault 0 "Mushroom" (inventory pEntity)
  in pMush / 20.0

-- | @ Mana
getMana :: EntityMap -> Double
getMana em = let
  (pEntity, _) = getPlayer em
  mp    = fromIntegral $ eMP pEntity
  maxMp = fromIntegral $ eMaxMP pEntity
  in if maxMp > 0.0 then mp / maxMp else 0.0

-- | @ lives at 0
-- getPlayer
getPlayer :: EntityMap -> (EntityKind, Coord)
getPlayer = GE.getEntityAt 0

-- | @ Potion
getPotion :: EntityMap -> Double
getPotion em = let
  (pEntity, _) = getPlayer em
  pPot = fromIntegral $ Map.findWithDefault 0 "Potion" (inventory pEntity)
  in pPot / 20.0

-- | @ Selection
selection :: [Text] -> [Text]
selection xs = let
  pSel = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"
        , "a", "b", "c", "d", "e", "f", "g", "h", "i", "j"]
  in [ loc | (k, v) <- zip pSel xs, let loc = T.concat [ k, ") ", v ] ]

-- | update @ properties
updatePlayer :: EntityKind -> EntityMap -> EntityMap
updatePlayer = Map.insert 0

-- | update @ position
updatePlayerBy :: Coord -> EntityMap -> EntityMap
updatePlayerBy = GE.updateEntityPos 0

-- | updateEntityXP
updatePlayerXP :: Int -> EntityMap -> EntityMap
updatePlayerXP xp em = let
  (pEntity, _ ) = getPlayer em
  pProp = property pEntity
  pCls     = Map.findWithDefault "None" "Class" pProp
  cAttacks = Map.findWithDefault "1" "ATTACKS" pProp
  cCast    = Map.findWithDefault "0" "CAST" pProp
  cProf    = Map.findWithDefault "0" "Proficiency" pProp
  cSearch  = Map.findWithDefault "0" "SEARCH" pProp
  cHP  = read $ T.unpack $ Map.findWithDefault "0" "HP" pProp :: Int
  cMP  = read $ T.unpack $ Map.findWithDefault "0" "MP" pProp :: Int
  pStr = read $ T.unpack $ Map.findWithDefault "1" "str" pProp :: Int
  pDex = read $ T.unpack $ Map.findWithDefault "1" "dex" pProp :: Int
  pCon = read $ T.unpack $ Map.findWithDefault "1" "con" pProp :: Int
  pInt = read $ T.unpack $ Map.findWithDefault "1" "int" pProp :: Int
  pWis = read $ T.unpack $ Map.findWithDefault "1" "wis" pProp :: Int
  (_, pConMod) = abilityLookup "con" pEntity
  (_, pWisMod) = abilityLookup "wis" pEntity
  -- Experience
  pTot    = eXP pEntity + xp
  pLvl    = xpLevel pTot
  current = eLvl pEntity
  -- HP
  pHP     = if pLvl > current then pMaxHP else eHP pEntity
  pHealth = pLvl * (cHP + pConMod)
  pMaxHP  = if pHealth > 0 then pHealth else cHP
  -- Fighter
  (fStr, fDex) = if pCls == "Fighter" then abilityGain pLvl current else (0,0)
  -- Rogue
  (rDex, rInt) = if pCls == "Rogue" then abilityGain pLvl current else (0,0)
  -- Mage
  (mInt, mWis) = if pCls == "Mage"  then abilityGain pLvl current else (0,0)
  -- Cleric
  (cWis, cStr) = if pCls == "Cleric" then abilityGain pLvl current else (0,0)
  -- Mana
  pMP    = if pLvl > current then pMaxMP else eMP pEntity
  pMana  = pLvl * (cMP + pWisMod)
  pMaxMP = if pMana > 0 then pMana else 0
  -- ATTACKS, CAST, PROFICIENCY, SEARCH
  pAttacks = attacksGain pCls pLvl cAttacks
  pCast    = castGain pCls pLvl cCast
  pProf    = proficiencyGain pLvl cProf
  pSearch  = searchGain pLvl cSearch
  -- Properties
  newProp = Map.fromList [ ("str", T.pack $ show $ pStr + fStr + cStr)
                         , ("dex", T.pack $ show $ pDex + fDex + rDex)
                         , ("con", T.pack $ show  pCon)
                         , ("int", T.pack $ show $ pInt + mInt + rInt)
                         , ("wis", T.pack $ show $ pWis + mWis + cWis)
                         , ("ATTACKS", pAttacks)
                         , ("CAST", pCast)
                         , ("Proficiency", pProf)
                         , ("SEARCH", pSearch)
                         ]
  newPlayer = pEntity { property = Map.union newProp pProp
                      , eLvl     = pLvl
                      , eHP      = pHP
                      , eMaxHP   = pMaxHP
                      , eMP      = pMP
                      , eMaxMP   = pMaxMP
                      , eXP      = pTot }
  in updatePlayer newPlayer em
