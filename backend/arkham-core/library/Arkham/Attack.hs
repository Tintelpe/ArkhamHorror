{-# LANGUAGE TemplateHaskell #-}
module Arkham.Attack where

import Arkham.Prelude

import Arkham.Id
import Arkham.Strategy
import Arkham.Target
import Data.Aeson.TH

data EnemyAttackType = AttackOfOpportunity | RegularAttack
  deriving stock (Show, Eq, Ord)

data EnemyAttackDetails = EnemyAttackDetails
  { attackTarget :: Target
  , attackEnemy :: EnemyId
  , attackType :: EnemyAttackType
  , attackDamageStrategy :: DamageStrategy
  , attackExhaustsEnemy :: Bool
  }
  deriving stock (Show, Eq, Ord)

enemyAttack :: Targetable target => EnemyId -> target -> EnemyAttackDetails
enemyAttack enemyId (toTarget -> target) = EnemyAttackDetails
  { attackTarget = target
  , attackEnemy = enemyId
  , attackType = RegularAttack
  , attackDamageStrategy = DamageAny
  , attackExhaustsEnemy = False
  }

attackOfOpportunity
  :: Targetable target => EnemyId -> target -> EnemyAttackDetails
attackOfOpportunity enemyId target =
  (enemyAttack enemyId target) { attackType = AttackOfOpportunity }

damageStrategyL :: Lens' EnemyAttackDetails DamageStrategy
damageStrategyL =
  lens attackDamageStrategy $ \m x -> m { attackDamageStrategy = x }

$(deriveJSON defaultOptions ''EnemyAttackType)
$(deriveJSON defaultOptions ''EnemyAttackDetails)
