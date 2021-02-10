module Arkham.Types.Investigator.Cards.WendyAdams
  ( WendyAdams(..)
  , wendyAdams
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


import Arkham.Types.Game.Helpers
import Arkham.Types.Investigator.Attrs
import Arkham.Types.Investigator.Runner
import Arkham.Types.Stats
import Arkham.Types.Trait

newtype WendyAdams = WendyAdams InvestigatorAttrs
  deriving newtype (Show, ToJSON, FromJSON, Entity)

instance HasModifiersFor env WendyAdams where
  getModifiersFor source target (WendyAdams attrs) =
    getModifiersFor source target attrs

wendyAdams :: WendyAdams
wendyAdams = WendyAdams $ baseAttrs
  "01005"
  "Wendy Adams"
  Survivor
  Stats
    { health = 7
    , sanity = 7
    , willpower = 4
    , intellect = 3
    , combat = 1
    , agility = 4
    }
  [Drifter]

instance HasTokenValue env WendyAdams where
  getTokenValue (WendyAdams attrs) iid ElderSign | iid == investigatorId attrs =
    pure $ TokenValue ElderSign (PositiveModifier 0)
  getTokenValue (WendyAdams attrs) iid token = getTokenValue attrs iid token

ability :: InvestigatorAttrs -> Token -> Ability
ability attrs token = base
  { abilityLimit = PlayerLimit PerTestOrAbility 1
  , abilityMetadata = Just (TargetMetadata $ TokenFaceTarget token)
  }
 where
  base = mkAbility
    (toSource attrs)
    1
    (ReactionAbility $ HandDiscardCost 1 Nothing mempty mempty)

instance ActionRunner env => HasActions env WendyAdams where
  getActions iid (WhenRevealToken You token) (WendyAdams attrs@InvestigatorAttrs {..})
    | iid == investigatorId
    = pure [ActivateCardAbilityAction investigatorId $ ability attrs token]
  getActions i window (WendyAdams attrs) = getActions i window attrs

instance (InvestigatorRunner env) => RunMessage env WendyAdams where
  runMessage msg i@(WendyAdams attrs@InvestigatorAttrs {..}) = case msg of
    UseCardAbility _ (InvestigatorSource iid) (Just (TargetMetadata (TokenFaceTarget token))) 1 _
      | iid == investigatorId
      -> do
        cancelToken token
        i <$ unshiftMessages
          [ CancelNext DrawTokenMessage
          , CancelNext RevealTokenMessage
          , ReturnTokens [token]
          , UnfocusTokens
          , DrawAnotherToken iid
          ]
    When (DrawToken iid token) | iid == investigatorId -> i <$ unshiftMessages
      [ FocusTokens [token]
      , CheckWindow investigatorId [WhenDrawToken You token]
      , UnfocusTokens
      ]
    ResolveToken _drawnToken ElderSign iid | iid == investigatorId -> do
      maid <- getId @(Maybe AssetId) (CardCode "01014")
      i <$ when (isJust maid) (unshiftMessage PassSkillTest)
    _ -> WendyAdams <$> runMessage msg attrs
