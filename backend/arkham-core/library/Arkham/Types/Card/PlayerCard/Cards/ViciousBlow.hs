module Arkham.Types.Card.PlayerCard.Cards.ViciousBlow where

import ClassyPrelude

import Arkham.Json
import Arkham.Types.Card.Id
import Arkham.Types.Card.PlayerCard.Attrs
import Arkham.Types.ClassSymbol
import Arkham.Types.SkillType
import Arkham.Types.Trait

newtype ViciousBlow = ViciousBlow Attrs
  deriving newtype (Show, ToJSON, FromJSON)

viciousBlow :: CardId -> ViciousBlow
viciousBlow cardId =
  ViciousBlow $ (skill cardId "01025" "Vicious Blow" [SkillCombat] Guardian)
    { pcTraits = [Practiced]
    }
