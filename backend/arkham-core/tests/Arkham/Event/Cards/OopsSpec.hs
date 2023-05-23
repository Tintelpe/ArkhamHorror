module Arkham.Event.Cards.OopsSpec (
  spec,
) where

import TestImport hiding (EnemyDamage)

import Arkham.Asset.Cards qualified as Assets
import Arkham.Asset.Types (Field (..))
import Arkham.Enemy.Types (Field (..))
import Arkham.Enemy.Types qualified as Enemy
import Arkham.Event.Cards qualified as Cards
import Arkham.Investigator.Types qualified as Investigator
import Arkham.Location.Types (revealCluesL)
import Arkham.Matcher (assetIs)
import Arkham.Projection

spec :: Spec
spec = describe "Oops!" $ do
  it "deals damage that attack would have done" $ gameTest $ \investigator -> do
    updateInvestigator investigator $
      (Investigator.combatL .~ 1)
        . (Investigator.resourcesL .~ 2)
    oops <- genCard Cards.oops
    enemy <- testEnemy $ (Enemy.healthL .~ Static 1) . (Enemy.fightL .~ 2)
    enemy2 <- testEnemy (Enemy.healthL .~ Static 3)
    location <- testLocation (revealCluesL .~ Static 0)

    pushAndRunAll
      [ SetTokens [MinusOne]
      , addToHand (toId investigator) oops
      , enemySpawn location enemy
      , enemySpawn location enemy2
      ]
    putCardIntoPlay investigator Assets.rolands38Special
    rolands38Special <- selectJust $ assetIs Assets.rolands38Special
    pushAndRun $ moveTo investigator location

    [doFight] <- field AssetAbilities rolands38Special
    pushAndRun $ UseAbility (toId investigator) doFight []
    chooseOptionMatching
      "fight enemy 1"
      ( \case
          FightLabel {enemyId} -> enemyId == toId enemy
          _ -> False
      )
    chooseOptionMatching
      "start skill test"
      ( \case
          StartSkillTestButton {} -> True
          _ -> False
      )
    chooseOnlyOption "apply results"
    chooseOptionMatching
      "play oops!"
      ( \case
          TargetLabel {} -> True
          _ -> False
      )
    fieldAssert EnemyDamage (== 0) enemy
    fieldAssert EnemyDamage (== 2) enemy2

  it "[FAQ] does not deal on success damage" $ gameTest $ \investigator -> do
    updateInvestigator investigator $
      (Investigator.combatL .~ 1)
        . (Investigator.resourcesL .~ 2)
    oops <- genCard Cards.oops
    enemy <- testEnemy $ (Enemy.healthL .~ Static 1) . (Enemy.fightL .~ 4)
    enemy2 <- testEnemy (Enemy.healthL .~ Static 3)
    location <- testLocation id

    pushAndRunAll
      [ SetTokens [MinusOne]
      , addToHand (toId investigator) oops
      , enemySpawn location enemy
      , enemySpawn location enemy2
      ]
    putCardIntoPlay investigator Assets.fortyOneDerringer
    fortyOneDerringer <- selectJust $ assetIs Assets.fortyOneDerringer
    pushAndRun $ moveTo investigator location

    [doFight] <- field AssetAbilities fortyOneDerringer
    pushAndRun $ UseAbility (toId investigator) doFight []
    chooseOptionMatching
      "fight enemy 1"
      ( \case
          FightLabel {enemyId} -> enemyId == toId enemy
          _ -> False
      )
    chooseOptionMatching
      "start skill test"
      ( \case
          StartSkillTestButton {} -> True
          _ -> False
      )
    chooseOnlyOption "apply results"
    chooseOptionMatching
      "play oops!"
      ( \case
          TargetLabel {} -> True
          _ -> False
      )
    fieldAssert EnemyDamage (== 0) enemy
    fieldAssert EnemyDamage (== 1) enemy2

  it "[FAQ] shotgun only deals 1 damage" $ gameTest $ \investigator -> do
    updateInvestigator investigator $
      (Investigator.combatL .~ 1)
        . (Investigator.resourcesL .~ 2)
    oops <- genCard Cards.oops
    enemy <- testEnemy $ (Enemy.healthL .~ Static 1) . (Enemy.fightL .~ 5)
    enemy2 <- testEnemy (Enemy.healthL .~ Static 3)
    location <- testLocation id

    pushAndRunAll
      [ SetTokens [MinusOne]
      , addToHand (toId investigator) oops
      , enemySpawn location enemy
      , enemySpawn location enemy2
      ]

    putCardIntoPlay investigator Assets.shotgun4
    shotgun4 <- selectJust $ assetIs Assets.shotgun4
    pushAndRun $ moveAllTo location
    [doFight] <- field AssetAbilities shotgun4
    pushAndRun $ UseAbility (toId investigator) doFight []
    chooseOptionMatching
      "fight enemy 1"
      ( \case
          FightLabel {enemyId} -> enemyId == toId enemy
          _ -> False
      )
    chooseOptionMatching
      "start skill test"
      ( \case
          StartSkillTestButton {} -> True
          _ -> False
      )
    chooseOnlyOption "apply results"
    chooseOptionMatching
      "play oops!"
      ( \case
          TargetLabel {} -> True
          _ -> False
      )
    fieldAssert EnemyDamage (== 0) enemy
    fieldAssert EnemyDamage (== 1) enemy2
