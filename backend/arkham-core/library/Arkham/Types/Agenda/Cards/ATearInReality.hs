module Arkham.Types.Agenda.Cards.ATearInReality
  ( ATearInReality(..)
  , aTearInReality
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


import Arkham.Types.Agenda.Attrs
import Arkham.Types.Agenda.Helpers
import Arkham.Types.Agenda.Runner

newtype ATearInReality = ATearInReality AgendaAttrs
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

aTearInReality :: ATearInReality
aTearInReality =
  ATearInReality $ baseAttrs "02160" "A Tear in Reality" (Agenda 1 A) (Static 4)

instance HasModifiersFor env ATearInReality where
  getModifiersFor = noModifiersFor

instance HasActions env ATearInReality where
  getActions i window (ATearInReality x) = getActions i window x

leftmostLocation
  :: (MonadReader env m, HasId (Maybe LocationId) env (Direction, LocationId))
  => LocationId
  -> m LocationId
leftmostLocation lid = do
  mlid' <- getId (LeftOf, lid)
  maybe (pure lid) leftmostLocation mlid'

instance AgendaRunner env => RunMessage env ATearInReality where
  runMessage msg a@(ATearInReality attrs@AgendaAttrs {..}) = case msg of
    AdvanceAgenda aid | aid == agendaId && agendaSequence == Agenda 1 B -> do
      leadInvestigatorId <- unLeadInvestigatorId <$> getId ()
      investigatorIds <- getInvestigatorIds
      locationId <- getId @LocationId leadInvestigatorId
      lid <- leftmostLocation locationId
      a <$ unshiftMessages
        (RemoveLocation lid
        : [ InvestigatorDiscardAllClues iid | iid <- investigatorIds ]
        <> [NextAgenda agendaId "02161"]
        )
    _ -> ATearInReality <$> runMessage msg attrs
