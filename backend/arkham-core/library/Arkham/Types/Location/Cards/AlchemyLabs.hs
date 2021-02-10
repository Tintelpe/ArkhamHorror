module Arkham.Types.Location.Cards.AlchemyLabs
  ( alchemyLabs
  , AlchemyLabs(..)
  ) where

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


import qualified Arkham.Types.Action as Action
import qualified Arkham.Types.EncounterSet as EncounterSet
import Arkham.Types.Location.Attrs
import Arkham.Types.Location.Helpers
import Arkham.Types.Location.Runner
import Arkham.Types.Trait

newtype AlchemyLabs = AlchemyLabs LocationAttrs
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

alchemyLabs :: AlchemyLabs
alchemyLabs = AlchemyLabs $ baseAttrs
  "02057"
  (Name "Alchemy Labs" Nothing)
  EncounterSet.ExtracurricularActivity
  5
  (Static 0)
  Squiggle
  [Hourglass]
  [Miskatonic]

instance HasModifiersFor env AlchemyLabs where
  getModifiersFor _ target (AlchemyLabs attrs) | isTarget attrs target =
    pure $ toModifiers attrs [ Blocked | not (locationRevealed attrs) ]
  getModifiersFor _ _ _ = pure []

instance ActionRunner env => HasActions env AlchemyLabs where
  getActions iid NonFast (AlchemyLabs attrs@LocationAttrs {..}) | locationRevealed =
    withBaseActions iid NonFast attrs $ do
      let
        ability = mkAbility
          (toSource attrs)
          1
          (ActionAbility (Just Action.Investigate) (ActionCost 1))
      pure
        [ ActivateCardAbilityAction iid ability
        | iid `elem` locationInvestigators
        ]
  getActions iid window (AlchemyLabs attrs) = getActions iid window attrs

instance LocationRunner env => RunMessage env AlchemyLabs where
  runMessage msg l@(AlchemyLabs attrs) = case msg of
    UseCardAbility iid source _ 1 _ | isSource attrs source ->
      l <$ unshiftMessage
        (Investigate iid (locationId attrs) source SkillIntellect False)
    SuccessfulInvestigation iid _ source | isSource attrs source -> do
      maid <- fmap unStoryAssetId <$> getId (CardCode "02059")
      l <$ case maid of
        Just aid -> unshiftMessage (TakeControlOfAsset iid aid)
        Nothing -> pure ()
    _ -> AlchemyLabs <$> runMessage msg attrs
