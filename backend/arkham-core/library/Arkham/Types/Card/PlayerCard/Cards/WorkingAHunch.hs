module Arkham.Types.Card.PlayerCard.Cards.WorkingAHunch where

import ClassyPrelude

import Arkham.Json
import Arkham.Types.Card.Id
import Arkham.Types.Card.PlayerCard.Attrs
import Arkham.Types.ClassSymbol
import Arkham.Types.SkillType
import Arkham.Types.Trait
import Arkham.Types.Window

newtype WorkingAHunch = WorkingAHunch Attrs
  deriving newtype (Show, ToJSON, FromJSON)

workingAHunch :: CardId -> WorkingAHunch
workingAHunch cardId =
  WorkingAHunch $ (event cardId "01037" "Working a Hunch" 2 Seeker)
    { pcSkills = [SkillIntellect, SkillIntellect]
    , pcTraits = [Insight]
    , pcFast = True
    , pcWindows = setFromList [DuringTurn You]
    }

