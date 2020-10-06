module Arkham.Types.Card.PlayerCard.Cards.HolyRosary where

import ClassyPrelude

import Arkham.Json
import Arkham.Types.Card.Id
import Arkham.Types.Card.PlayerCard.Attrs
import Arkham.Types.ClassSymbol
import Arkham.Types.SkillType
import Arkham.Types.Trait

newtype HolyRosary = HolyRosary Attrs
  deriving newtype (Show, ToJSON, FromJSON)

holyRosary :: CardId -> HolyRosary
holyRosary cardId = HolyRosary $ (asset cardId "01059" "Holy Rosary" 2 Mystic)
  { pcSkills = [SkillWillpower]
  , pcTraits = [Item, Charm]
  }
