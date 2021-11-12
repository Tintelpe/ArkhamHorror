module Arkham.Types.Enemy.Cards.Maniac
  ( maniac
  , Maniac(..)
  ) where

import Arkham.Prelude

import Arkham.Enemy.Cards qualified as Cards
import Arkham.Types.Ability
import Arkham.Types.Classes
import Arkham.Types.Enemy.Attrs
import Arkham.Types.Matcher
import Arkham.Types.Message
import Arkham.Types.Source
import Arkham.Types.Timing qualified as Timing

newtype Maniac = Maniac EnemyAttrs
  deriving anyclass (IsEnemy, HasModifiersFor env)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

instance HasAbilities Maniac where
  getAbilities (Maniac a) =
    [ mkAbility a 1
        $ ForcedAbility
        $ EnemyEngaged Timing.After You
        $ EnemyWithId
        $ toId a
    ]

maniac :: EnemyCard Maniac
maniac = enemy Maniac Cards.maniac (3, Static 4, 1) (1, 0)

instance EnemyRunner env => RunMessage env Maniac where
  runMessage msg e@(Maniac attrs) = case msg of
    UseCardAbility iid source _ 1 _ | isSource attrs source -> e <$ pushAll
      [ InvestigatorAssignDamage iid source DamageAny 1 0
      , Damage (toTarget attrs) (InvestigatorSource iid) 1
      ]
    _ -> Maniac <$> runMessage msg attrs
