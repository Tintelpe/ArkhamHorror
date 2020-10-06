module Arkham.Types.Card.PlayerCard.Cards.WrackedByNightmares where

import ClassyPrelude

import Arkham.Json
import Arkham.Types.Card.Id
import Arkham.Types.Card.PlayerCard.Attrs
import Arkham.Types.Trait

newtype WrackedByNightmares = WrackedByNightmares Attrs
  deriving newtype (Show, ToJSON, FromJSON)

wrackedByNightmares :: CardId -> WrackedByNightmares
wrackedByNightmares cardId =
  WrackedByNightmares $ (treachery cardId "02015" "Wracked by Nightmares" 0)
    { pcTraits = [Madness]
    , pcRevelation = True
    }

