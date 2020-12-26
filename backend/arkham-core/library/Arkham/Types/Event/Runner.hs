{-# LANGUAGE UndecidableInstances #-}
module Arkham.Types.Event.Runner where

import Arkham.Types.AssetId
import Arkham.Types.Card
import Arkham.Types.Classes
import Arkham.Types.EnemyId
import Arkham.Types.InvestigatorId
import Arkham.Types.LocationId
import Arkham.Types.Query
import Arkham.Types.Target
import Arkham.Types.Trait

type EventRunner env
  = ( HasQueue env
    , HasCount ClueCount env InvestigatorId
    , HasCount ClueCount env LocationId
    , HasCount PlayerCount env ()
    , HasId LocationId env InvestigatorId
    , HasList DiscardableHandCard env InvestigatorId
    , HasRoundHistory env
    , HasSet AssetId env InvestigatorId
    , HasSet AssetId env (InvestigatorId, [Trait])
    , HasSet ConnectedLocationId env LocationId
    , HasSet EmptyLocationId env ()
    , HasSet EnemyId env InvestigatorId
    , HasSet EnemyId env LocationId
    , HasSet ExhaustedEnemyId env LocationId
    , HasSet InvestigatorId env ()
    , HasSet InvestigatorId env LocationId
    , HasSet RevealedLocationId env ()
    , HasSet Trait env AssetId
    , HasSet Trait env EnemyId
    , HasTarget ForSkillTest env
    )
