{-# LANGUAGE DeriveGeneric #-}
{-

Game.Kind.Entity.hs

Author: "Joel E Carlson" <joel.elmer.carlson@gmail.com>

-}
module Game.Kind.Entity (AssetMap
                        , EntityMap
                        , Entity(..)
                        , EntityKind(..)
                        , Inventory
                        , NameMap
                        , Properties) where

import Prelude hiding (lookup)
import Data.Aeson
import Data.Map (Map)
import Data.Text (Text)
import GHC.Generics
import Game.Kind.Visual

-- | Maps used within the game
type AssetMap = Map Int EntityKind
type EntityMap = Map Int EntityKind
type Inventory = Map Text Int
type NameMap = Map Text EntityKind
type Properties = Map Text Text

type Coord = (Int, Int)

-- | Entity stack sort...
data Entity
  = Actor
  | Monster
  | Item
  | Coin
  | Corpse
  | Arrow
  | Mushroom
  | Potion
  | Trap
  | StairDown
  | StairUp
  deriving (Ord, Show, Eq, Generic)

instance FromJSON Entity
instance ToJSON Entity

-- | EntityKind
-- coord     = Entity Position
-- block     = Movable Entity
-- kind      = Kind of Entity
-- glyph     = VisualKind of Entity
-- moveT     = Where can the Entity move?
-- spawn     = Where can the Entity spawn?
-- property  = Textual descriptions of the entity
-- inventory = Items
-- eLvl      = Level of the entity
-- eHP       = HitPoint
-- eMaxHP    = Max HP
-- eMP       = ManaPoint
-- eMaxMP    = Max MP
-- eXP       = Experience
data EntityKind = EntityKind
  { coord      :: Coord
  , block      :: Bool
  , kind       :: Entity
  , glyph      :: VisualKind
  , moveT      :: [Coord]
  , spawn      :: Coord
  , property   :: Properties
  , inventory  :: Inventory
  , eLvl       :: Int
  , eHP        :: Int
  , eMaxHP     :: Int
  , eMP        :: Int
  , eMaxMP     :: Int
  , eXP        :: Int
  } deriving (Show, Generic)

instance FromJSON EntityKind
instance ToJSON EntityKind
