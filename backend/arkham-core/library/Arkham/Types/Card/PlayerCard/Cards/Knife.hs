module Arkham.Types.Card.PlayerCard.Cards.Knife where

import ClassyPrelude

import Arkham.Json
import Arkham.Types.Card.Id
import Arkham.Types.Card.PlayerCard.Attrs
import Arkham.Types.ClassSymbol
import Arkham.Types.SkillType
import Arkham.Types.Trait

newtype Knife = Knife Attrs
  deriving newtype (Show, ToJSON, FromJSON)

knife :: CardId -> Knife
knife cardId = Knife $ (asset cardId "01086" "Knife" 1 Neutral)
  { pcSkills = [SkillCombat]
  , pcTraits = [Item, Weapon, Melee]
  }
