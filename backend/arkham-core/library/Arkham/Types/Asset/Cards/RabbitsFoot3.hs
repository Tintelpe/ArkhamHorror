module Arkham.Types.Asset.Cards.RabbitsFoot3
  ( RabbitsFoot3(..)
  , rabbitsFoot3
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


import Arkham.Types.Asset.Attrs
import Arkham.Types.Asset.Runner

newtype RabbitsFoot3 = RabbitsFoot3 AssetAttrs
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

rabbitsFoot3 :: AssetId -> RabbitsFoot3
rabbitsFoot3 uuid =
  RabbitsFoot3 $ (baseAttrs uuid "50010") { assetSlots = [AccessorySlot] }

instance HasModifiersFor env RabbitsFoot3 where
  getModifiersFor = noModifiersFor

ability :: AssetAttrs -> Int -> Ability
ability attrs n =
  (mkAbility (toSource attrs) 1 (ReactionAbility $ ExhaustCost (toTarget attrs))
    )
    { abilityMetadata = Just (IntMetadata n)
    }

instance HasActions env RabbitsFoot3 where
  getActions iid (AfterFailSkillTest You n) (RabbitsFoot3 a) | ownedBy a iid =
    pure [ActivateCardAbilityAction iid (ability a n)]
  getActions i window (RabbitsFoot3 x) = getActions i window x

instance AssetRunner env => RunMessage env RabbitsFoot3 where
  runMessage msg a@(RabbitsFoot3 attrs) = case msg of
    UseCardAbility iid source (Just (IntMetadata x)) 1 _
      | isSource attrs source -> a <$ unshiftMessage
        (SearchTopOfDeck iid (InvestigatorTarget iid) x mempty ShuffleBackIn)
    _ -> RabbitsFoot3 <$> runMessage msg attrs
