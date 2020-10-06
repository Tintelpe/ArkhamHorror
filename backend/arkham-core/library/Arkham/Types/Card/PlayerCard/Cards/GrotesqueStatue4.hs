module Arkham.Types.Card.PlayerCard.Cards.GrotesqueStatue4 where

import ClassyPrelude

import Arkham.Json
import Arkham.Types.Card.Id
import Arkham.Types.Card.PlayerCard.Attrs
import Arkham.Types.ClassSymbol
import Arkham.Types.SkillType
import Arkham.Types.Trait

newtype GrotesqueStatue4 = GrotesqueStatue4 Attrs
  deriving newtype (Show, ToJSON, FromJSON)

grotesqueStatue4 :: CardId -> GrotesqueStatue4
grotesqueStatue4 cardId = GrotesqueStatue4
  (asset cardId "01071" "Grotesque Statue" 2 Mystic)
    { pcSkills = [SkillWild]
    , pcTraits = [Item, Relic]
    , pcLevel = 4
    }
