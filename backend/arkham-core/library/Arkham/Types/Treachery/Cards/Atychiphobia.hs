module Arkham.Types.Treachery.Cards.Atychiphobia
  ( atychiphobia
  , Atychiphobia(..)
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

newtype Atychiphobia = Atychiphobia TreacheryAttrs
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

atychiphobia :: TreacheryId -> Maybe InvestigatorId -> Atychiphobia
atychiphobia uuid iid = Atychiphobia $ weaknessAttrs uuid iid "60504"

instance HasModifiersFor env Atychiphobia where
  getModifiersFor = noModifiersFor

instance ActionRunner env => HasActions env Atychiphobia where
  getActions iid NonFast (Atychiphobia a@TreacheryAttrs {..}) =
    withTreacheryInvestigator a $ \tormented -> do
      investigatorLocationId <- getId @LocationId iid
      treacheryLocation <- getId tormented
      pure
        [ ActivateCardAbilityAction
            iid
            (mkAbility (toSource a) 1 (ActionAbility Nothing $ ActionCost 2))
        | treacheryLocation == investigatorLocationId
        ]
  getActions _ _ _ = pure []

instance (TreacheryRunner env) => RunMessage env Atychiphobia where
  runMessage msg t@(Atychiphobia attrs@TreacheryAttrs {..}) = case msg of
    Revelation iid source | isSource attrs source ->
      t <$ unshiftMessage (AttachTreachery treacheryId $ InvestigatorTarget iid)
    FailedSkillTest iid _ _ _ _ _ | treacheryOnInvestigator iid attrs ->
      t <$ unshiftMessage
        (InvestigatorAssignDamage
          iid
          (TreacherySource treacheryId)
          DamageAny
          0
          1
        )
    UseCardAbility _ (TreacherySource tid) _ 1 _ | tid == treacheryId ->
      t <$ unshiftMessage (Discard (TreacheryTarget treacheryId))
    _ -> Atychiphobia <$> runMessage msg attrs
