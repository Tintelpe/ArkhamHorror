module Arkham.Types.Asset.Cards.LeoDeLuca where

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


import Arkham.Types.Asset.Attrs
import Arkham.Types.Asset.Helpers
import Arkham.Types.Asset.Runner

newtype LeoDeLuca = LeoDeLuca AssetAttrs
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

leoDeLuca :: AssetId -> LeoDeLuca
leoDeLuca uuid = LeoDeLuca $ (baseAttrs uuid "01048")
  { assetSlots = [AllySlot]
  , assetHealth = Just 2
  , assetSanity = Just 2
  }

instance HasModifiersFor env LeoDeLuca where
  getModifiersFor _ (InvestigatorTarget iid) (LeoDeLuca a) =
    pure [ toModifier a (AdditionalActions 1) | ownedBy a iid ]
  getModifiersFor _ _ _ = pure []

instance HasActions env LeoDeLuca where
  getActions i window (LeoDeLuca x) = getActions i window x

instance (AssetRunner env) => RunMessage env LeoDeLuca where
  runMessage msg (LeoDeLuca attrs@AssetAttrs {..}) = case msg of
    InvestigatorPlayAsset iid aid _ _ | aid == assetId -> do
      unshiftMessage $ GainActions iid (AssetSource aid) 1
      LeoDeLuca <$> runMessage msg attrs
    _ -> LeoDeLuca <$> runMessage msg attrs
