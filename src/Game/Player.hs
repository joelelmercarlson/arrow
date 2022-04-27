{-# LANGUAGE OverloadedStrings #-}
{-

Game.Player.hs

Game.Player is the engine for the Actor EntityKind. This is used
as interchangable helper functions for id=0

Example: getPlayer returns the Player from the EntityMap

Author: "Joel E Carlson" <joel.elmer.carlson@gmail.com>

-}
module Game.Player (characterSheet
                   , characterInventory
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
import Data.Map (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe
import Data.Text (Text)
import qualified Data.Text as T
import Game.Entity (EntityMap)
import qualified Game.Entity as GE
import Game.Kind.Entity (EntityKind(..))

type Coord = (Int, Int)
type Player = EntityKind
type AssetMap = EntityMap
type Inventory = Map Text Int

-- | abilityMod
abilityMod :: Int -> Int
abilityMod n = (n-10) `div` 2

-- | @ Stats
characterSheet :: EntityMap -> [Text]
characterSheet em = let
  (pEntity, _) = getPlayer em
  pInv   = inventory pEntity
  pCoin  = T.append "AU: " (T.pack $ show $ Map.findWithDefault 0 "Coin" pInv)
  pEquip = T.concat [ equip "melee" "|" pInv
    , equip "shoot"   "{" pInv
    , equip "jewelry" "=" pInv
    , equip "neck"    "\"" pInv
    , equip "armor"   "[" pInv
    , equip "cloak"   "(" pInv
    , equip "shield"  ")" pInv
    , equip "head"    "]" pInv
    , equip "hands"   "]" pInv
    , equip "feet"    "]" pInv
    ]
  pProp = property pEntity
  pStr  = T.append "Str: " (Map.findWithDefault "1" "str" pProp)
  pDex  = T.append "Dex: " (Map.findWithDefault "1" "dex" pProp)
  pCon  = T.append "Con: " (Map.findWithDefault "1" "con" pProp)
  pInt  = T.append "Int: " (Map.findWithDefault "1" "int" pProp)
  pWis  = T.append "Wis: " (Map.findWithDefault "1" "wis" pProp)
  pLvl  = T.pack $ "Level: " ++ show (eLvl pEntity)
  pExp  = T.pack $ "EXP: " ++ show (eXP pEntity)
  in [ pLvl, pExp, pCoin, pEquip, pStr, pDex, pCon, pInt, pWis ]

-- | @ Inv
characterInventory :: EntityMap -> AssetMap -> [Text]
characterInventory em am = let
  (pEntity, _) = getPlayer em
  descMap = Map.fromList $
    [ (k, v) | (_, ek) <- Map.toList am,
      let k = fromMaybe "I" (Map.lookup "Name" (property ek))
          v = fromMaybe "~" (Map.lookup "Description" (property ek)) ]
  pInv = [ i | (k, v) <- Map.toList (inventory pEntity),
           let i = T.append k (T.pack $ " '" ++ desc ++ "': " ++ show v)
               desc = T.unpack $ fromMaybe "I" (Map.lookup k descMap) ]
  in pInv ++ [" ", "Press ESC, I to Continue..."]

-- | @ equipment
equip :: Text -> Text -> Inventory -> Text
equip name desc items = let
  count :: Text -> Text -> Int
  count x xs = length $
    filter (==x) (T.words $ fst $ T.breakOn "/" xs)
  item = sum $ [ x :: Int | (k, _) <- Map.toList items, let x = equipped k ]
  equipped n
    | count name n > 0 = 1
    | otherwise = 0
  in if item > 0 then desc else "."

-- | @ lives at 0
-- Arrow for Player
getArrow :: EntityMap -> Double
getArrow em = let
  (pEntity, _) = getPlayer em
  pArrow = fromIntegral $ Map.findWithDefault 0 "Arrow" (inventory pEntity)
  in pArrow / 20.0

-- | @ lives at 0
-- Health for Player
getHealth :: EntityMap -> Double
getHealth em = let
  (pEntity, _) = getPlayer em
  hp    = fromIntegral $ eHP pEntity
  maxHp = fromIntegral $ eMaxHP pEntity
  in hp / maxHp

-- | @ lives at 0
-- Mushroom for Player
getMushroom :: EntityMap -> Double
getMushroom em = let
  (pEntity, _) = getPlayer em
  pMush = fromIntegral $ Map.findWithDefault 0 "Mushroom" (inventory pEntity)
  in pMush / 20.0

-- | @ lives at 0
-- Mana for Player
getMana :: EntityMap -> Double
getMana em = let
  (pEntity, _) = getPlayer em
  mp    = fromIntegral $ eMP pEntity
  maxMp = fromIntegral $ eMaxMP pEntity
  in mp / maxMp

-- | @ lives at 0
-- getPlayer
getPlayer :: EntityMap -> (Player, Coord)
getPlayer = GE.getEntityAt 0

-- | @ lives at 0
-- Potion for Player
getPotion :: EntityMap -> Double
getPotion em = let
  (pEntity, _) = getPlayer em
  pPot = fromIntegral $ Map.findWithDefault 0 "Potion" (inventory pEntity)
  in pPot / 20.0

-- | @ gets better with level
proficiency :: Int -> Int
proficiency lvl
  | lvl >= 1  && lvl <= 4 = 2
  | lvl >= 5  && lvl <= 8 = 3
  | lvl >= 9  && lvl <= 12 = 4
  | lvl >= 13 && lvl <= 16 = 5
  | lvl >= 17 && lvl <= 20 = 6
  | otherwise = 2

-- | update @ properties
updatePlayer :: Player -> EntityMap -> EntityMap
updatePlayer = Map.insert 0

-- | update @ position
updatePlayerBy :: Coord -> EntityMap -> EntityMap
updatePlayerBy = GE.updateEntityPos 0

-- | updateEntityXP at ix
updatePlayerXP :: Int -> EntityMap -> EntityMap
updatePlayerXP xp em = let
  (pEntity, _ ) = getPlayer em
  pProp     = property pEntity
  pCon      = read $ T.unpack $ Map.findWithDefault "1" "con" pProp
  pWis      = read $ T.unpack $ Map.findWithDefault "1" "wis" pProp
  cHP       = read $ T.unpack $ Map.findWithDefault "1" "HP" pProp
  cMP       = read $ T.unpack $ Map.findWithDefault "1" "MP" pProp
  pTot      = eXP pEntity + xp
  pLvl      = xpLevel pTot
  pHP       = if pLvl > eLvl pEntity then pMaxHP else eHP pEntity
  pMaxHP    = pLvl * (cHP + abilityMod pCon)
  pMP       = if pLvl > eLvl pEntity then pMaxMP else eMP pEntity
  pMaxMP    = pLvl * (cMP + abilityMod pWis)
  newProp   = Map.insert "Proficiency" (T.pack $ show $ proficiency pLvl) pProp
  newPlayer = pEntity { property=newProp
                      , eLvl=pLvl
                      , eHP=pHP
                      , eMaxHP=pMaxHP
                      , eMP=pMP
                      , eMaxMP=pMaxMP
                      , eXP=pTot }
  in updatePlayer newPlayer em

-- | xpLevel simple
xpLevel :: Int -> Int
xpLevel x
  | x > 0    && x <= 35  = 1
  | x > 35   && x <= 100 = 2
  | x > 100  && x <= 200 = 3
  | x > 200  && x <= 300 = 4
  | x > 300  && x <= 400 = 5
  | x > 400  && x <= 600 = 6
  | x > 600  && x <= 800 = 7
  | x > 800  && x <= 1000 = 8
  | x > 1000 && x <= 1200 = 9
  | x > 1200 && x <= 1400 = 10
  | x > 1400 && x <= 1600 = 11
  | x > 1600 && x <= 2000 = 12
  | x > 2000 && x <= 3000 = 13
  | x > 3000 && x <= 4600 = 14
  | x > 4000 && x <= 5000 = 15
  | x > 5000 && x <= 6000 = 16
  | x > 6000 && x <= 7000 = 17
  | x > 7000 && x <= 8000 = 18
  | x > 8000 && x <= 10000 = 19
  | x > 10000              = 20
  | otherwise = 1
