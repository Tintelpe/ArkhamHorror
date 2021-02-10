module Arkham.Types.Skill.Cards.DoubleOrNothing
  ( doubleOrNothing
  , DoubleOrNothing(..)
  )
where

import Arkham.Prelude

import Arkham.Json
import Arkham.Types.Ability
import Arkham.Types.ActId
import Arkham.Types.AgendaId
import Arkham.Types.AssetId
import Arkham.Types.CampaignId
import Arkham.Types.Card
import Arkham.Types.Card.Cost
import Arkham.Types.Card.Id
import Arkham.Types.Classes
import Arkham.Types.ClassSymbol
import Arkham.Types.Cost
import Arkham.Types.Direction
import Arkham.Types.Effect.Window
import Arkham.Types.EffectId
import Arkham.Types.EffectMetadata
import Arkham.Types.EncounterSet (EncounterSet)
import Arkham.Types.EnemyId
import Arkham.Types.EventId
import Arkham.Types.Exception
import Arkham.Types.GameValue
import Arkham.Types.Helpers
import Arkham.Types.InvestigatorId
import Arkham.Types.LocationId
import Arkham.Types.LocationMatcher
import Arkham.Types.LocationSymbol
import Arkham.Types.Message
import Arkham.Types.Modifier
import Arkham.Types.Name
import Arkham.Types.Prey
import Arkham.Types.Query
import Arkham.Types.Resolution
import Arkham.Types.ScenarioId
import Arkham.Types.SkillId
import Arkham.Types.SkillType
import Arkham.Types.Slot
import Arkham.Types.Source
import Arkham.Types.Stats (Stats)
import Arkham.Types.Target
import Arkham.Types.Token
import Arkham.Types.TreacheryId
import Arkham.Types.Window


import Arkham.Types.Game.Helpers
import Arkham.Types.Skill.Attrs
import Arkham.Types.Skill.Runner

newtype DoubleOrNothing = DoubleOrNothing SkillAttrs
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

doubleOrNothing :: InvestigatorId -> SkillId -> DoubleOrNothing
doubleOrNothing iid uuid = DoubleOrNothing $ baseAttrs iid uuid "02026"

instance HasModifiersFor env DoubleOrNothing where
  getModifiersFor _ SkillTestTarget (DoubleOrNothing attrs) =
    pure $ toModifiers attrs [DoubleDifficulty, DoubleSuccess]
  getModifiersFor _ _ _ = pure []

instance HasActions env DoubleOrNothing where
  getActions iid window (DoubleOrNothing attrs) = getActions iid window attrs

instance SkillRunner env => RunMessage env DoubleOrNothing where
  runMessage msg (DoubleOrNothing attrs) =
    DoubleOrNothing <$> runMessage msg attrs
