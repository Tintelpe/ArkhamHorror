module Arkham.Types.Location.Cards.EngineCar_177
  ( engineCar_177
  , EngineCar_177(..)
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


import qualified Arkham.Types.EncounterSet as EncounterSet
import Arkham.Types.Location.Attrs
import Arkham.Types.Location.Helpers
import Arkham.Types.Location.Runner
import Arkham.Types.Trait

newtype EngineCar_177 = EngineCar_177 LocationAttrs
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

engineCar_177 :: EngineCar_177
engineCar_177 = EngineCar_177
  $ base { locationVictory = Just 1, locationConnectsTo = singleton LeftOf }
 where
  base = baseAttrs
    "02177"
    (Name "Engine Car" Nothing)
    EncounterSet.TheEssexCountyExpress
    1
    (PerPlayer 2)
    NoSymbol
    []
    (singleton Train)

instance HasCount ClueCount env LocationId => HasModifiersFor env EngineCar_177 where
  getModifiersFor _ target (EngineCar_177 location@LocationAttrs {..})
    | isTarget location target = case lookup LeftOf locationDirections of
      Just leftLocation -> do
        clueCount <- unClueCount <$> getCount leftLocation
        pure $ toModifiers
          location
          [ Blocked | not locationRevealed && clueCount > 0 ]
      Nothing -> pure []
  getModifiersFor _ _ _ = pure []

instance ActionRunner env => HasActions env EngineCar_177 where
  getActions iid window (EngineCar_177 attrs) = getActions iid window attrs

instance LocationRunner env => RunMessage env EngineCar_177 where
  runMessage msg (EngineCar_177 attrs) = case msg of
    RevealLocation (Just iid) lid | lid == locationId attrs -> do
      unshiftMessages (replicate 3 $ InvestigatorDrawEncounterCard iid)
      EngineCar_177 <$> runMessage msg attrs
    _ -> EngineCar_177 <$> runMessage msg attrs
