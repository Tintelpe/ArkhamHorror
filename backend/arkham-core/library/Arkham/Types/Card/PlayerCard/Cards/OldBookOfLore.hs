module Arkham.Types.Card.PlayerCard.Cards.OldBookOfLore where

import ClassyPrelude

import Arkham.Json
import Arkham.Types.Card.Id
import Arkham.Types.Card.PlayerCard.Attrs
import Arkham.Types.ClassSymbol
import Arkham.Types.SkillType
import Arkham.Types.Trait

newtype OldBookOfLore = OldBookOfLore Attrs
  deriving newtype (Show, ToJSON, FromJSON)

oldBookOfLore :: CardId -> OldBookOfLore
oldBookOfLore cardId =
  OldBookOfLore $ (asset cardId "01031" "Old Book of Lore" 3 Seeker)
    { pcSkills = [SkillWillpower]
    , pcTraits = [Item, Tome]
    }
