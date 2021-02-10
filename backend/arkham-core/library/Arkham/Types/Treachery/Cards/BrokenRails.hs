module Arkham.Types.Treachery.Cards.BrokenRails
  ( brokenRails
  , BrokenRails(..)
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


import Arkham.Types.Treachery.Attrs
import Arkham.Types.Treachery.Runner

newtype BrokenRails = BrokenRails TreacheryAttrs
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

brokenRails :: TreacheryId -> a -> BrokenRails
brokenRails uuid _ = BrokenRails $ baseAttrs uuid "02181"

instance HasModifiersFor env BrokenRails where
  getModifiersFor = noModifiersFor

instance HasActions env BrokenRails where
  getActions i window (BrokenRails attrs) = getActions i window attrs

instance TreacheryRunner env => RunMessage env BrokenRails where
  runMessage msg t@(BrokenRails attrs@TreacheryAttrs {..}) = case msg of
    Revelation iid source | isSource attrs source -> do
      lid <- getId @LocationId iid
      investigatorIds <- getSetList lid
      investigatorsWhoMustDiscard <- flip filterM investigatorIds $ \iid' -> do
        damageCount <- unDamageCount <$> getCount iid'
        pure $ damageCount >= 4
      t <$ unshiftMessages
        ([ LoseActions iid' source 1 | iid' <- investigatorIds ]
        <> [ ChooseAndDiscardAsset iid'
           | iid' <- investigatorsWhoMustDiscard
           ]
        <> [Discard (toTarget attrs)]
        )
    _ -> BrokenRails <$> runMessage msg attrs
