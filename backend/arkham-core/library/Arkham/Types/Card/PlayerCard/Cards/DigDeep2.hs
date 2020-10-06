module Arkham.Types.Card.PlayerCard.Cards.DigDeep2 where

import ClassyPrelude

import Arkham.Json
import Arkham.Types.Card.Id
import Arkham.Types.Card.PlayerCard.Attrs
import Arkham.Types.ClassSymbol
import Arkham.Types.SkillType
import Arkham.Types.Trait

newtype DigDeep2 = DigDeep2 Attrs
  deriving newtype (Show, ToJSON, FromJSON)

digDeep2 :: CardId -> DigDeep2
digDeep2 cardId = DigDeep2 (asset cardId "50009" "Dig Deep" 0 Survivor)
  { pcSkills = [SkillWillpower, SkillWillpower, SkillAgility, SkillAgility]
  , pcTraits = [Talent]
  , pcLevel = 2
  }
