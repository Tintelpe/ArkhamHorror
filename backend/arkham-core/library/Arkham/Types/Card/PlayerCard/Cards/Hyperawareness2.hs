module Arkham.Types.Card.PlayerCard.Cards.Hyperawareness2 where

import ClassyPrelude

import Arkham.Json
import Arkham.Types.Card.Id
import Arkham.Types.Card.PlayerCard.Attrs
import Arkham.Types.ClassSymbol
import Arkham.Types.SkillType
import Arkham.Types.Trait

newtype Hyperawareness2 = Hyperawareness2 Attrs
  deriving newtype (Show, ToJSON, FromJSON)

hyperawareness2 :: CardId -> Hyperawareness2
hyperawareness2 cardId =
  Hyperawareness2 $ (asset cardId "50003" "Hyperawareness" 0 Seeker)
    { pcSkills = [SkillIntellect, SkillIntellect, SkillAgility, SkillAgility]
    , pcTraits = [Talent]
    , pcLevel = 2
    }
