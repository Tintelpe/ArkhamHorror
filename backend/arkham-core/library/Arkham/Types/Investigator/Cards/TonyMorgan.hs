module Arkham.Types.Investigator.Cards.TonyMorgan where

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


import Arkham.Types.Investigator.Attrs
import Arkham.Types.Investigator.Runner
import Arkham.Types.Stats
import Arkham.Types.Trait

newtype TonyMorgan = TonyMorgan InvestigatorAttrs
  deriving newtype (Show, ToJSON, FromJSON, Entity)

instance HasModifiersFor env TonyMorgan where
  getModifiersFor source target (TonyMorgan attrs) =
    getModifiersFor source target attrs

tonyMorgan :: TonyMorgan
tonyMorgan = TonyMorgan $ baseAttrs
  "06003"
  "Tony Morgan"
  Rogue
  Stats
    { health = 9
    , sanity = 5
    , willpower = 2
    , intellect = 3
    , combat = 5
    , agility = 2
    }
  [Criminal, Hunter]

instance ActionRunner env => HasActions env TonyMorgan where
  getActions i window (TonyMorgan attrs) = getActions i window attrs

instance (InvestigatorRunner env) => RunMessage env TonyMorgan where
  runMessage msg (TonyMorgan attrs) = TonyMorgan <$> runMessage msg attrs
