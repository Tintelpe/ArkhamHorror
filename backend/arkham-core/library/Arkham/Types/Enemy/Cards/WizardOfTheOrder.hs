{-# LANGUAGE UndecidableInstances #-}
module Arkham.Types.Enemy.Cards.WizardOfTheOrder where

import Arkham.Json
import Arkham.Types.Classes
import Arkham.Types.Enemy.Attrs
import Arkham.Types.Enemy.Runner
import Arkham.Types.EnemyId
import Arkham.Types.GameValue
import Arkham.Types.Message
import ClassyPrelude
import Lens.Micro

newtype WizardOfTheOrder = WizardOfTheOrder Attrs
  deriving newtype (Show, ToJSON, FromJSON)

wizardOfTheOrder :: EnemyId -> WizardOfTheOrder
wizardOfTheOrder uuid = WizardOfTheOrder $ (baseAttrs uuid "01170")
  { enemyHealthDamage = 1
  , enemyFight = 4
  , enemyHealth = Static 2
  , enemyEvade = 2
  }

instance (IsInvestigator investigator) => HasActions investigator WizardOfTheOrder where
  getActions i (WizardOfTheOrder attrs) = getActions i attrs

instance (EnemyRunner env) => RunMessage env WizardOfTheOrder where
  runMessage msg e@(WizardOfTheOrder attrs@Attrs {..}) = case msg of
    InvestigatorDrawEnemy iid _ eid | eid == enemyId ->
      e <$ spawnAtEmptyLocation iid eid
    EndMythos -> pure $ WizardOfTheOrder $ attrs & doom +~ 1
    _ -> WizardOfTheOrder <$> runMessage msg attrs
