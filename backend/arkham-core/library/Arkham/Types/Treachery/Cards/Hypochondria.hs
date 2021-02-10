module Arkham.Types.Treachery.Cards.Hypochondria
  ( Hypochondria(..)
  , hypochondria
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


import Arkham.Types.Treachery.Attrs
import Arkham.Types.Treachery.Runner

newtype Hypochondria = Hypochondria TreacheryAttrs
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

hypochondria :: TreacheryId -> Maybe InvestigatorId -> Hypochondria
hypochondria uuid iid = Hypochondria $ weaknessAttrs uuid iid "01100"

instance HasModifiersFor env Hypochondria where
  getModifiersFor = noModifiersFor

instance ActionRunner env => HasActions env Hypochondria where
  getActions iid NonFast (Hypochondria a@TreacheryAttrs {..}) =
    withTreacheryInvestigator a $ \tormented -> do
      treacheryLocation <- getId tormented
      investigatorLocationId <- getId @LocationId iid
      pure
        [ ActivateCardAbilityAction
            iid
            (mkAbility (toSource a) 1 (ActionAbility Nothing $ ActionCost 2))
        | treacheryLocation == investigatorLocationId
        ]
  getActions _ _ _ = pure []

instance (TreacheryRunner env) => RunMessage env Hypochondria where
  runMessage msg t@(Hypochondria attrs@TreacheryAttrs {..}) = case msg of
    Revelation iid source | isSource attrs source ->
      t <$ unshiftMessage (AttachTreachery treacheryId $ InvestigatorTarget iid)
    After (InvestigatorTakeDamage iid _ n _)
      | treacheryOnInvestigator iid attrs && n > 0 -> t <$ unshiftMessage
        (InvestigatorDirectDamage iid (TreacherySource treacheryId) 0 1)
    UseCardAbility _ (TreacherySource tid) _ 1 _ | tid == treacheryId ->
      t <$ unshiftMessage (Discard (TreacheryTarget treacheryId))
    _ -> Hypochondria <$> runMessage msg attrs
