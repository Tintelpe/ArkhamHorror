module Arkham.Types.Location.Cards.ReturnToCellar where

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


import qualified Arkham.Types.EncounterSet as EncounterSet
import Arkham.Types.Location.Attrs
import Arkham.Types.Location.Runner

newtype ReturnToCellar = ReturnToCellar LocationAttrs
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

returnToCellar :: ReturnToCellar
returnToCellar = ReturnToCellar $ baseAttrs
  "50020"
  (Name "Cellar" Nothing)
  EncounterSet.ReturnToTheGathering
  2
  (PerPlayer 1)
  Plus
  [Square, Squiggle]
  mempty

instance HasModifiersFor env ReturnToCellar where
  getModifiersFor = noModifiersFor

instance ActionRunner env => HasActions env ReturnToCellar where
  getActions i window (ReturnToCellar attrs) = getActions i window attrs

instance (LocationRunner env) => RunMessage env ReturnToCellar where
  runMessage msg (ReturnToCellar attrs) = case msg of
    RevealLocation _ lid | lid == locationId attrs -> do
      unshiftMessage (PlaceLocation "50021")
      ReturnToCellar <$> runMessage msg attrs
    _ -> ReturnToCellar <$> runMessage msg attrs
