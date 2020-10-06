module Arkham.Types.Card.PlayerCard.Cards.BlindingLight where

import ClassyPrelude

import qualified Arkham.Types.Action as Action
import Arkham.Json
import Arkham.Types.Card.Id
import Arkham.Types.Card.PlayerCard.Attrs
import Arkham.Types.ClassSymbol
import Arkham.Types.SkillType
import Arkham.Types.Trait

newtype BlindingLight = BlindingLight Attrs
  deriving newtype (Show, ToJSON, FromJSON)

blindingLight :: CardId -> BlindingLight
blindingLight cardId = BlindingLight
  (event cardId "01066" "Blinding Light" 2 Mystic)
    { pcSkills = [SkillWillpower, SkillAgility]
    , pcTraits = [Spell]
    , pcAction = Just Action.Evade
    }
