{-# LANGUAGE StrictData #-}
{-# LANGUAGE TemplateHaskell #-}
{-# OPTIONS_GHC -Wno-orphans #-}
module Arkham.Game where

import Arkham.Prelude

import Arkham.Ability
import Arkham.Act
import Arkham.Act.Attrs ( ActAttrs (..), Field (..) )
import Arkham.Act.Sequence ( actStep )
import Arkham.Action ( Action, TakenAction )
import Arkham.Action qualified as Action
import Arkham.Agenda
import Arkham.Agenda.Attrs ( AgendaAttrs (..), Field (..) )
import Arkham.Asset
import Arkham.Asset.Attrs ( AssetAttrs (..), Field (..) )
import Arkham.Asset.Uses ( UseType )
import Arkham.Attack
import Arkham.Campaign
import Arkham.Campaign.Attrs
import Arkham.CampaignId
import Arkham.Card
import Arkham.Card.EncounterCard
import Arkham.Card.Id
import Arkham.Card.PlayerCard
import Arkham.ChaosBag
import Arkham.Classes hiding ( getDistance )
import Arkham.ClassSymbol
import Arkham.Cost
import Arkham.Deck qualified as Deck
import Arkham.Decks
import Arkham.Difficulty
import Arkham.Direction
import Arkham.Distance
import Arkham.Effect
import Arkham.Effect.Attrs
import Arkham.EffectMetadata
import Arkham.EncounterCard.Source
import Arkham.Enemy
import Arkham.Enemy.Attrs ( EnemyAttrs (..), Field (..) )
import Arkham.Entities
import Arkham.Event
import Arkham.Event.Attrs
import Arkham.Game.Helpers hiding (getSpendableClueCount)
import {-# SOURCE #-} Arkham.GameEnv
import Arkham.Helpers
import Arkham.Helpers.Investigator
import Arkham.History
import Arkham.Id
import Arkham.Investigator
import Arkham.Investigator.Attrs ( Field (..), InvestigatorAttrs (..) )
import Arkham.Keyword ( HasKeywords (..), Keyword )
import Arkham.Keyword qualified as Keyword
import Arkham.Label qualified as L
import Arkham.Location
import Arkham.Location.Attrs ( Field (..), LocationAttrs (..) )
import Arkham.LocationSymbol
import Arkham.Matcher hiding
  ( AssetDefeated
  , AssetExhausted
  , Discarded
  , DuringTurn
  , EncounterCardSource
  , EnemyAttacks
  , EnemyDefeated
  , FastPlayerWindow
  , InvestigatorDefeated
  , InvestigatorEliminated
  , PlayCard
  , RevealLocation
  , AssetCard
  , EventCard
  )
import Arkham.Matcher qualified as M
import Arkham.Message hiding ( AssetDamage )
import Arkham.Message qualified as Msg
import Arkham.Modifier hiding ( EnemyEvade )
import Arkham.ModifierData
import Arkham.Name
import Arkham.Phase
import Arkham.PlayerCard
import Arkham.Projection
import Arkham.Query hiding ( InvestigatorLocation )
import Arkham.Scenario
import Arkham.Scenario.Attrs
import Arkham.Scenario.Deck
import Arkham.ScenarioLogKey
import Arkham.Skill
import Arkham.Skill.Attrs ( Field(..), SkillAttrs (..) )
import Arkham.SkillTest.Runner
import Arkham.SkillType
import Arkham.Slot
import Arkham.Source
import Arkham.Target
import Arkham.Timing qualified as Timing
import Arkham.Token
import Arkham.Trait
import Arkham.Treachery
import Arkham.Treachery.Attrs ( Field(..), TreacheryAttrs (..) )
import Arkham.Window ( Window (..) )
import Arkham.Window qualified as Window
import Arkham.Zone ( Zone )
import Arkham.Zone qualified as Zone
import Control.Lens ( each, itraverseOf, itraversed, set )
import Control.Monad.Random ( StdGen, mkStdGen )
import Control.Monad.Reader ( runReader )
import Control.Monad.State.Strict hiding ( filterM, foldM, state )
import Data.Aeson.Diff qualified as Diff
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.TH
import Data.Align hiding ( nil )
import Data.HashMap.Strict ( size )
import Data.HashMap.Strict qualified as HashMap
import Data.List.Extra ( groupOn )
import Data.Monoid ( First (..) )
import Data.Sequence qualified as Seq
import Data.These
import Data.These.Lens
import Data.UUID ( nil )
import Safe ( headNote )
import System.Environment
import Text.Pretty.Simple

type GameMode = These Campaign Scenario
data GameState = IsPending | IsActive | IsOver
  deriving stock (Eq, Show)

$(deriveJSON defaultOptions ''GameState)

data GameParams = GameParams
  (Either ScenarioId CampaignId)
  Int
  [(Investigator, [PlayerCard])] -- Map for order
  Difficulty
  deriving stock (Eq, Show)

$(deriveJSON defaultOptions ''GameParams)

data Game = Game
  { gamePhaseHistory :: HashMap InvestigatorId History
  , gameTurnHistory :: HashMap InvestigatorId History
  , gameRoundHistory :: HashMap InvestigatorId History
  , gameInitialSeed :: Int
  , gameSeed :: Int
  , gameParams :: GameParams
  , gameWindowDepth :: Int
  , -- Active Scenario/Campaign
    gameMode :: GameMode
  , -- Entities
    gameEntities :: Entities
  , gameEncounterDiscardEntities :: Entities
  , gameInHandEntities :: HashMap InvestigatorId Entities
  , gameInDiscardEntities :: HashMap InvestigatorId Entities
  , gameInSearchEntities :: Entities
  , gameEnemiesInVoid :: EntityMap Enemy
  , -- Player Details
    gamePlayerCount :: Int -- used for determining if game should start
  , gameActiveInvestigatorId :: InvestigatorId
  , gameTurnPlayerInvestigatorId :: Maybe InvestigatorId
  , gameLeadInvestigatorId :: InvestigatorId
  , gamePlayerOrder :: [InvestigatorId] -- For "in player order"
  , -- Game Details
    gamePhase :: Phase
  , gameSkillTest :: Maybe SkillTest
  , gameFocusedCards :: [Card]
  , gameFoundCards :: HashMap Zone [Card]
  , gameFocusedTargets :: [Target]
  , gameFocusedTokens :: [Token]
  , gameActiveCard :: Maybe Card
  , gameRemovedFromPlay :: [Card]
  , gameGameState :: GameState
  , gameSkillTestResults :: Maybe SkillTestResultsData
  , gameEnemyMoving :: Maybe EnemyId
  , -- Active questions
    gameQuestion :: HashMap InvestigatorId (Question Message)
  }
  deriving stock (Eq, Show)

$(deriveJSON defaultOptions ''Game)

makeLensesWith suffixedFields ''Game


-- the issue is the following we want GameT
-- which has GameEnv as the environment
-- GameEnv contains Game
-- Game references entities like Investigator
-- Which references every Investigator
-- which references InvestigatorAttrs
-- All of which now need to know about GameT

class HasGameRef a where
  gameRefL :: Lens' a (IORef Game)

class HasGame m where
  getGame :: m Game

class HasStdGen a where
  genL :: Lens' a (IORef StdGen)

newCampaign
  :: MonadIO m
  => CampaignId
  -> Int
  -> Int
  -> [(Investigator, [PlayerCard])]
  -> Difficulty
  -> m (IORef [Message], Game)
newCampaign = newGame . Right

newScenario
  :: MonadIO m
  => ScenarioId
  -> Int
  -> Int
  -> [(Investigator, [PlayerCard])]
  -> Difficulty
  -> m (IORef [Message], Game)
newScenario = newGame . Left

newGame
  :: MonadIO m
  => Either ScenarioId CampaignId
  -> Int
  -> Int
  -> [(Investigator, [PlayerCard])]
  -> Difficulty
  -> m (IORef [Message], Game)
newGame scenarioOrCampaignId seed playerCount investigatorsList difficulty = do
  let
    state =
      if length investigatorsMap /= playerCount then IsPending else IsActive
  ref <- newIORef $ if state == IsActive
    then
      map (uncurry InitDeck . bimap toId Deck) investigatorsList
        <> [StartCampaign]
    else []

  pure
    ( ref
    , Game
      { gameParams = GameParams
        scenarioOrCampaignId
        playerCount
        investigatorsList
        difficulty
      , gameWindowDepth = 0
      , gameRoundHistory = mempty
      , gamePhaseHistory = mempty
      , gameTurnHistory = mempty
      , gameInitialSeed = seed
      , gameSeed = seed
      , gameMode = mode
      , gamePlayerCount = playerCount
      , gameEntities = defaultEntities { entitiesInvestigators = investigatorsMap }
      , gameEncounterDiscardEntities = defaultEntities
      , gameInHandEntities = mempty
      , gameInDiscardEntities = mempty
      , gameInSearchEntities = defaultEntities
      , gameEnemiesInVoid = mempty
      , gameActiveInvestigatorId = initialInvestigatorId
      , gameTurnPlayerInvestigatorId = Nothing
      , gameLeadInvestigatorId = initialInvestigatorId
      , gamePhase = CampaignPhase
      , gameSkillTest = Nothing
      , gameGameState = state
      , gameFocusedCards = mempty
      , gameFoundCards = mempty
      , gameFocusedTargets = mempty
      , gameFocusedTokens = mempty
      , gameActiveCard = Nothing
      , gamePlayerOrder = toList playersMap
      , gameRemovedFromPlay = mempty
      , gameQuestion = mempty
      , gameSkillTestResults = Nothing
      , gameEnemyMoving = Nothing
      }
    )
 where
  initialInvestigatorId =
    toId . fst . headNote "No investigators" $ toList investigatorsList
  playersMap = map (toId . fst) investigatorsList
  investigatorsMap =
    mapFromList $ map (toFst toId . fst) (toList investigatorsList)
  campaign = either
    (const Nothing)
    (Just . (`lookupCampaign` difficulty))
    scenarioOrCampaignId
  scenario = either
    (Just . (`lookupScenario` difficulty))
    (const Nothing)
    scenarioOrCampaignId
  mode = fromJustNote "Need campaign or scenario" $ align campaign scenario

addInvestigator :: Investigator -> [PlayerCard] -> GameT ()
addInvestigator i d = do
  gameRef <- view gameRefL
  game <- liftIO $ readIORef gameRef
  queueRef <- view messageQueue

  let
    iid = toId i
    g' = game & (entitiesL . investigatorsL %~ insertEntity i) & (playerOrderL <>~ [iid])
    gameState = if size (g' ^. entitiesL . investigatorsL) < g' ^. playerCountL
      then IsPending
      else IsActive

  let
    GameParams scenarioOrCampaignId playerCount investigatorsList difficulty =
      gameParams game
    investigatorsList' = investigatorsList <> [(i, d)]

  when (gameState == IsActive) $ atomicWriteIORef
    queueRef
    (map (uncurry InitDeck . bimap toId Deck) investigatorsList'
    <> [StartCampaign]
    )

  atomicWriteIORef
    gameRef
    (g'
    & (gameStateL .~ gameState)
    -- Adding players causes RNG split so we reset the initial seed on each player
    -- being added so that choices can replay correctly
    & (initialSeedL .~ gameSeed game)
    & (paramsL
      .~ GameParams
           scenarioOrCampaignId
           playerCount
           investigatorsList'
           difficulty
      )
    )

-- TODO: Rename this
toExternalGame :: MonadRandom m => Game -> HashMap InvestigatorId (Question Message) -> m Game
toExternalGame g mq = do
  newGameSeed <- getRandom
  pure $ g { gameQuestion = mq, gameSeed = newGameSeed }

replayChoices :: [Diff.Patch] -> GameT ()
replayChoices choices = do
  gameRef <- view gameRefL
  genRef <- view genL
  currentGame <- readIORef gameRef
  writeIORef genRef (mkStdGen (gameInitialSeed currentGame))

  let
    GameParams scenarioOrCampaignId playerCount investigatorsList difficulty =
      gameParams currentGame

  (_, replayedGame) <- newGame
    scenarioOrCampaignId
    (gameInitialSeed currentGame)
    playerCount
    investigatorsList
    difficulty

  case foldM patch replayedGame (reverse choices) of
    Error e -> error e
    Success g -> writeIORef gameRef g

modeScenario :: GameMode -> Maybe Scenario
modeScenario = \case
  That s -> Just s
  These _ s -> Just s
  This _ -> Nothing

modeCampaign :: GameMode -> Maybe Campaign
modeCampaign = \case
  That _ -> Nothing
  These c _ -> Just c
  This c -> Just c

diff :: Game -> Game -> Diff.Patch
diff a b = Diff.diff (toJSON a) (toJSON b)

patch :: Game -> Diff.Patch -> Result Game
patch g p = case Diff.patch p (toJSON g) of
  Error e -> Error e
  Success a -> fromJSON a

getScenario :: GameT (Maybe Scenario)
getScenario = modeScenario . view modeL <$> getGame

getCampaign :: GameT (Maybe Campaign)
getCampaign = modeCampaign . view modeL <$> getGame

withModifiers :: a -> GameT (With a ModifierData)
withModifiers a = do
  source <- InvestigatorSource . unActiveInvestigatorId <$> getId ()
  modifiers' <- getModifiersFor source (toTarget a) ()
  pure $ a `with` ModifierData modifiers'

withLocationConnectionData
  :: With Location ModifierData
  -> GameT (With (With Location ModifierData) ConnectionData)
withLocationConnectionData inner@(With target _) = do
  matcher <- getConnectedMatcher target
  connectedLocationIds <- selectList matcher
  pure $ inner `with` ConnectionData connectedLocationIds

withInvestigatorConnectionData
  :: With WithDeckSize ModifierData
  -> GameT (With (With WithDeckSize ModifierData) ConnectionData)
withInvestigatorConnectionData inner@(With target _) = case target of
  WithDeckSize investigator -> do
    location <- getLocation =<< getId @LocationId (toId investigator)
    matcher <- getConnectedMatcher location
    connectedLocationIds <- selectList (AccessibleLocation <> matcher)
    pure $ inner `with` ConnectionData connectedLocationIds

newtype WithDeckSize = WithDeckSize Investigator
  deriving newtype TargetEntity

instance ToJSON WithDeckSize where
  toJSON (WithDeckSize i) = case toJSON i of
    Object o ->
      Object $ KeyMap.insert "deckSize" (toJSON $ length $ investigatorDeck $ toAttrs i) o
    _ -> error "failed to serialize investigator"

withSkillTestModifiers :: SkillTest -> a -> GameT (With a ModifierData)
withSkillTestModifiers st a = do
  modifiers' <- getModifiersFor (toSource st) (toTarget a) ()
  pure $ a `with` ModifierData modifiers'

gameSkills :: Game -> EntityMap Skill
gameSkills = entitiesSkills . gameEntities

gameEvents :: Game -> EntityMap Event
gameEvents = entitiesEvents . gameEntities

gameEffects :: Game -> EntityMap Effect
gameEffects = entitiesEffects . gameEntities

gameActs :: Game -> EntityMap Act
gameActs = entitiesActs . gameEntities

gameAgendas :: Game -> EntityMap Agenda
gameAgendas = entitiesAgendas . gameEntities

gameEnemies :: Game -> EntityMap Enemy
gameEnemies = entitiesEnemies . gameEntities

gameLocations :: Game -> EntityMap Location
gameLocations = entitiesLocations . gameEntities

gameInvestigators :: Game -> EntityMap Investigator
gameInvestigators = entitiesInvestigators . gameEntities

gameAssets :: Game -> EntityMap Asset
gameAssets = entitiesAssets . gameEntities

gameTreacheries :: Game -> EntityMap Treachery
gameTreacheries = entitiesTreacheries . gameEntities

data PublicGame gid = PublicGame gid Text [Text] Game
  deriving stock Show

instance ToJSON gid => ToJSON (PublicGame gid) where
  toJSON (PublicGame gid name glog g@Game {..}) = object
    [ "name" .= toJSON name
    , "id" .= toJSON gid
    , "log" .= toJSON glog
    , "mode" .= toJSON gameMode
    , "locations" .= toJSON
      (runReader
        (traverse withLocationConnectionData
        =<< traverse withModifiers (gameLocations g)
        )
        g
      )
    , "investigators" .= toJSON
      (runReader
        (traverse withInvestigatorConnectionData
        =<< traverse (withModifiers . WithDeckSize) (gameInvestigators g)
        )
        g
      )
    , "enemies" .= toJSON (runReader (traverse withModifiers (gameEnemies g)) g)
    , "enemiesInVoid"
      .= toJSON (runReader (traverse withModifiers gameEnemiesInVoid) g)
    , "assets" .= toJSON (runReader (traverse withModifiers (gameAssets g)) g)
    , "acts" .= toJSON (runReader (traverse withModifiers (gameActs g)) g)
    , "agendas" .= toJSON (runReader (traverse withModifiers (gameAgendas g)) g)
    , "treacheries"
      .= toJSON (runReader (traverse withModifiers (gameTreacheries g)) g)
    , "events" .= toJSON (runReader (traverse withModifiers (gameEvents g)) g)
    , "skills" .= toJSON (gameSkills g) -- no need for modifiers... yet
    , "playerCount" .= toJSON gamePlayerCount
    , "activeInvestigatorId" .= toJSON gameActiveInvestigatorId
    , "turnPlayerInvestigatorId" .= toJSON gameTurnPlayerInvestigatorId
    , "leadInvestigatorId" .= toJSON gameLeadInvestigatorId
    , "playerOrder" .= toJSON gamePlayerOrder
    , "phase" .= toJSON gamePhase
    , "skillTest" .= toJSON gameSkillTest
    , "skillTestTokens" .= toJSON
      (runReader
        (maybe
          (pure [])
          (\st ->
            traverse (withSkillTestModifiers st) (skillTestSetAsideTokens st)
          )
          gameSkillTest
        )
        g
      )
    , "focusedCards" .= toJSON gameFocusedCards
    , "foundCards" .= toJSON gameFoundCards
    , "focusedTargets" .= toJSON gameFocusedTargets
    , "focusedTokens"
      .= toJSON (runReader (traverse withModifiers gameFocusedTokens) g)
    , "activeCard" .= toJSON gameActiveCard
    , "removedFromPlay" .= toJSON gameRemovedFromPlay
    , "gameState" .= toJSON gameGameState
    , "skillTestResults" .= toJSON gameSkillTestResults
    , "question" .= toJSON gameQuestion
    ]

getInvestigator :: InvestigatorId -> GameT Investigator
getInvestigator iid =
  fromJustNote missingInvestigator
    . preview (entitiesL . investigatorsL . ix iid)
    <$> getGame
  where missingInvestigator = "Unknown investigator: " <> show iid

getLocation :: LocationId -> GameT Location
getLocation lid =
  fromJustNote missingLocation . preview (entitiesL . locationsL . ix lid) <$> getGame
  where missingLocation = "Unknown location: " <> show lid

getEffectsMatching
  :: EffectMatcher
  -> GameT [Effect]
getEffectsMatching _matcher = pure []

getCampaignssMatching
  :: CampaignsMatcher
  -> GameT [Campaigns]
getCampaignssMatching _matcher = pure []

getInvestigatorsMatching
  :: InvestigatorMatcher
  -> GameT [Investigator]
getInvestigatorsMatching matcher = do
  investigators <- toList . view (entitiesL . investigatorsL) <$> getGame
  filterM (go matcher) investigators
 where
  go = \case
    NoOne -> pure . const False
    FewestCardsInHand -> \i -> do
      cardCount <- unCardCount <$> getCount i
      minCardCount <- fromMaybe 100 . minimumMay . map unCardCount <$> getSetList ()
      pure $ minCardCount == cardCount
    LowestRemainingHealth -> \i -> do
      h <- getRemainingHealth i
      lowestRemainingHealth <-
        fromJustNote "has to be"
        . minimumMay
        . map unRemainingHealth
        <$> getSetList ()
      pure $ lowestRemainingHealth == h
    LowestRemainingSanity -> \i -> do
      remainingSanity <- getRemainingSanity i
      lowestRemainingSanity <-
        fromJustNote "has to be"
        . minimumMay
        . map unRemainingSanity
        <$> getSetList ()
      pure $ lowestRemainingSanity == remainingSanity
    MostRemainingSanity -> \i -> do
      remainingSanity <- getRemainingSanity i
      mostRemainingSanity <-
        fromJustNote "has to be"
        . maximumMay
        . map unRemainingSanity
        <$> getSetList ()
      pure $ mostRemainingSanity == remainingSanity
    MostHorror -> \i -> do
      let horrorCount = investigatorSanityDamage (toAttrs i)
      mostHorrorCount <- fromMaybe 0 . maximumMay . map unHorrorCount <$> getSetList ()
      pure $ mostHorrorCount == horrorCount
    NearestToEnemy enemyMatcher -> \i -> do
      mappings :: [(InvestigatorId, Distance)] <- getList enemyMatcher
      let
        mappingsMap :: HashMap InvestigatorId Distance = mapFromList mappings
        minDistance :: Int =
          fromJustNote "error" . minimumMay $ map (unDistance . snd) mappings
        investigatorDistance :: Int = unDistance $ findWithDefault
          (error "investigator not found")
          (toId i)
          mappingsMap
      pure $ investigatorDistance == minDistance
    HasMostMatchingAsset assetMatcher -> \i -> do
      selfCount <- length <$> selectList
        (assetMatcher <> AssetControlledBy (InvestigatorWithId $ toId i))
      allCounts <-
        traverse
            (\iid' ->
              length <$> selectList
                (assetMatcher <> AssetControlledBy (InvestigatorWithId iid'))
            )
          =<< getInvestigatorIds
      pure $ selfCount == maximum (ncons selfCount allCounts)
    HasMatchingAsset assetMatcher -> \i ->
      selectAny (assetMatcher <> AssetControlledBy (InvestigatorWithId $ toId i))
    HasMatchingEvent eventMatcher -> \i ->
      selectAny (eventMatcher <> EventControlledBy (InvestigatorWithId $ toId i))
    HasMatchingSkill skillMatcher -> \i ->
      selectAny (skillMatcher <> SkillControlledBy (InvestigatorWithId $ toId i))
    MostClues -> \i -> do
      clueCount <- unClueCount <$> getCount i
      mostClueCount <- fromMaybe 0 . maximumMay . map unClueCount <$> getSetList ()
      pure $ mostClueCount == clueCount
    You -> \i -> do
      you <- getInvestigator . view activeInvestigatorIdL =<< getGame
      pure $ you == i
    NotYou -> \i -> do
      you <- getInvestigator . view activeInvestigatorIdL =<< getGame
      pure $ you /= i
    Anyone -> pure . const True
    TurnInvestigator -> \i -> maybe False (== i) <$> getTurnInvestigator
    YetToTakeTurn -> \i -> andM
      [ maybe True (/= i) <$> getTurnInvestigator
      , pure $ not $ investigatorEndedTurn $ toAttrs i
      ]
    LeadInvestigator -> \i -> (== toId i) <$> getLeadInvestigatorId
    InvestigatorWithTitle title -> pure . (== title) . nameTitle . toName
    InvestigatorAt locationMatcher -> \i ->
      if locationOf i == LocationId (CardId nil)
        then pure False
        else member (locationOf i) <$> select locationMatcher
    InvestigatorWithId iid -> pure . (== iid) . toId
    InvestigatorWithLowestSkill skillType -> \i -> do
      lowestSkillValue <- fromMaybe 100 . minimumMay <$> getSetList skillType
      skillValue <- getSkillValue skillType i
      pure $ lowestSkillValue == skillValue
    InvestigatorWithHighestSkill skillType -> \i -> do
      highestSkillValue <- fromMaybe 0 . maximumMay <$> getSetList skillType
      skillValue <- getSkillValue skillType i
      pure $ highestSkillValue == skillValue
    InvestigatorWithClues gameValueMatcher ->
      getCount >=> (`gameValueMatches` gameValueMatcher) . unClueCount
    InvestigatorWithResources gameValueMatcher ->
      getCount >=> (`gameValueMatches` gameValueMatcher) . unResourceCount
    InvestigatorWithActionsRemaining gameValueMatcher ->
      getCount
        >=> (`gameValueMatches` gameValueMatcher)
        . unActionRemainingCount
    InvestigatorWithDamage gameValueMatcher ->
      (`gameValueMatches` gameValueMatcher) . fst . getDamage
    InvestigatorWithHorror gameValueMatcher ->
      (`gameValueMatches` gameValueMatcher) . snd . getDamage
    InvestigatorWithRemainingSanity gameValueMatcher ->
      getRemainingSanity >=> (`gameValueMatches` gameValueMatcher)
    InvestigatorMatches xs -> \i -> allM (`go` i) xs
    AnyInvestigator xs -> \i -> anyM (`go` i) xs
    HandWith cardListMatcher -> (`cardListMatches` cardListMatcher) . handOf
    DiscardWith cardListMatcher ->
      (`cardListMatches` cardListMatcher) . map PlayerCard . discardOf
    InvestigatorWithoutModifier modifierType -> \i -> do
      modifiers' <- getModifiers (toSource i) (toTarget i)
      pure $ modifierType `notElem` modifiers'
    UneliminatedInvestigator -> pure . not . isEliminated
    ResignedInvestigator -> pure . isResigned
    InvestigatorEngagedWith enemyMatcher -> \i -> do
      enemyIds <- select enemyMatcher
      any (`member` enemyIds) <$> getSet i
    TopCardOfDeckIs cardMatcher -> \i -> do
      deck <- getList i
      pure $ case deck of
        [] -> False
        x : _ -> cardMatch (unDeckCard x) cardMatcher
    UnengagedInvestigator -> fmap null . getSet @EnemyId
    NoDamageDealtThisTurn -> \i -> do
      history <- getHistory TurnHistory (toId i)
      pure $ notNull (historyDealtDamageTo history)
    ContributedMatchingIcons valueMatcher -> \i -> do
      mSkillTest <- getSkillTest
      case mSkillTest of
        Nothing -> pure False
        Just st -> do
          skillTestCount <- length <$> getList @CommittedSkillIcon (toId i, st)
          gameValueMatches skillTestCount valueMatcher

getAgendasMatching :: AgendaMatcher -> GameT [Agenda]
getAgendasMatching matcher = do
  allGameAgendas <- toList . view (entitiesL . agendasL) <$> getGame
  filterM (matcherFilter matcher) allGameAgendas
 where
  matcherFilter = \case
    AnyAgenda -> pure . const True
    AgendaWithId agendaId -> pure . (== agendaId) . toId
    AgendaWithDoom gameValueMatcher -> getCount >=> (`gameValueMatches` gameValueMatcher) . unDoomCount

getActsMatching :: ActMatcher -> GameT [Act]
getActsMatching matcher = do
  allGameActs <- toList . view (entitiesL . actsL) <$> getGame
  filterM (matcherFilter matcher) allGameActs
 where
  matcherFilter = \case
    AnyAct -> pure . const True
    ActWithId actId -> pure . (== actId) . toId

getRemainingActsMatching :: RemainingActMatcher -> GameT [CardDef]
getRemainingActsMatching matcher = do
  acts <-
    scenarioActs
    . fromJustNote "scenario has to be set"
    . modeScenario
    . view modeL
    <$> getGame
  activeActIds <- keys . view (entitiesL . actsL) <$> getGame
  let
    currentActId = case activeActIds of
      [aid] -> aid
      _ -> error "Cannot handle multiple acts"
    (_, _ : remainingActs) =
      break ((== currentActId) . ActId . toCardCode) acts
  filterM (matcherFilter $ unRemainingActMatcher matcher) remainingActs
 where
  matcherFilter = \case
    AnyAct -> pure . const True
    ActWithId _ -> pure . const False

getTreacheriesMatching :: TreacheryMatcher -> GameT [Treachery]
getTreacheriesMatching matcher = do
  pure []
--   allGameTreacheries <- toList . view (entitiesL . treacheriesL) <$> getGame
--   filterM (matcherFilter matcher) allGameTreacheries
--  where
--   matcherFilter = \case
--     AnyTreachery -> pure . const True
--     TreacheryWithTitle title -> pure . (== title) . nameTitle . toName
--     TreacheryWithFullTitle title subtitle ->
--       pure . (== Name title (Just subtitle)) . toName
--     TreacheryWithId treacheryId -> pure . (== treacheryId) . toId
--     TreacheryWithTrait t -> fmap (member t) . getSet . toId
--     TreacheryIs cardCode -> pure . (== cardCode) . toCardCode
--     TreacheryAt locationMatcher -> \treachery -> do
--       locations <- selectList locationMatcher
--       matches <- concat <$> traverse getSetList locations
--       pure $ toId treachery `elem` matches
--     TreacheryInHandOf investigatorMatcher -> \treachery -> do
--       iids <- select investigatorMatcher
--       pure $ case treacheryInHandOf treachery of
--         Just iid -> iid `member` iids
--         Nothing -> False
--     TreacheryInThreatAreaOf investigatorMatcher -> \treachery -> do
--       iids <- selectList investigatorMatcher
--       matches <- concat <$> traverse getSetList iids
--       pure $ toId treachery `elem` matches
--     TreacheryOwnedBy investigatorMatcher -> \treachery -> do
--       iids <- select investigatorMatcher
--       pure $ case treacheryOwner treachery of
--         Just iid -> iid `member` iids
--         Nothing -> False
--     TreacheryMatches matchers ->
--       \treachery -> allM (`matcherFilter` treachery) matchers

getScenariosMatching :: ScenarioMatcher -> GameT [Scenario]
getScenariosMatching _ = pure []

getAbilitiesMatching
  :: AbilityMatcher -> GameT [Ability]
getAbilitiesMatching matcher = guardYourLocation $ \_ -> do
  g <- getGame
  let abilities = getAbilities g
  case matcher of
    AnyAbility -> pure abilities
    AbilityOnLocation locationMatcher ->
      concatMap getAbilities
        <$> (traverse getLocation =<< selectList locationMatcher)
    AbilityIsAction action ->
      pure $ filter ((== Just action) . abilityAction) abilities
    AbilityIsActionAbility -> pure $ filter abilityIsActionAbility abilities
    AbilityWindow windowMatcher ->
      pure $ filter ((== windowMatcher) . abilityWindow) abilities
    AbilityMatches [] -> pure []
    AbilityMatches (x : xs) ->
      toList
        <$> (foldl' intersection
            <$> (setFromList @(HashSet Ability) <$> getAbilitiesMatching x)
            <*> traverse (fmap setFromList . getAbilitiesMatching) xs
            )
    AbilityOnScenarioCard -> filterM
      ((`sourceMatches` M.EncounterCardSource) . abilitySource)
      abilities

getLocationMatching
  :: LocationMatcher
  -> GameT (Maybe Location)
getLocationMatching = (listToMaybe <$>) . getLocationsMatching

getLocationsMatching
  :: LocationMatcher
  -> GameT [Location]
getLocationsMatching = \case
  FirstLocation [] -> pure []
  FirstLocation xs ->
    fromMaybe []
      . getFirst
      <$> foldM
            (\b a ->
              (b <>)
                . First
                . (\s -> if null s then Nothing else Just s)
                <$> getLocationsMatching a
            )
            (First Nothing)
            xs
  LocationWithLabel label ->
    filter ((== label) . toLocationLabel)
      . toList
      . view (entitiesL . locationsL)
      <$> getGame
  LocationWithTitle title ->
    filter ((== title) . nameTitle . toName)
      . toList
      . view (entitiesL . locationsL)
      <$> getGame
  LocationWithFullTitle title subtitle ->
    filter ((== Name title (Just subtitle)) . toName)
      . toList
      . view (entitiesL . locationsL)
      <$> getGame
  LocationWithUnrevealedTitle title ->
    filter ((== title) . nameTitle . toName . Unrevealed)
      . toList
      . view (entitiesL . locationsL)
      <$> getGame
  LocationWithId locationId ->
    filter ((== locationId) . toId) . toList . view (entitiesL . locationsL) <$> getGame
  LocationWithSymbol locationSymbol ->
    filter ((== locationSymbol) . toLocationSymbol)
      . toList
      . view (entitiesL . locationsL)
      <$> getGame
  LocationNotInPlay -> pure [] -- TODO: Should this check out of play locations
  Anywhere -> toList . view (entitiesL . locationsL) <$> getGame
  Unblocked -> do
    filterM (\l -> notElem Blocked <$> getModifiers (toSource l) (toTarget l))
      . toList
      . view (entitiesL . locationsL)
      =<< getGame
  LocationIs cardCode ->
    filter ((== cardCode) . toCardCode) . toList . view (entitiesL . locationsL) <$> getGame
  EmptyLocation ->
    filter isEmptyLocation . toList . view (entitiesL . locationsL) <$> getGame
  LocationWithoutInvestigators ->
    filter noInvestigatorsAtLocation . toList . view (entitiesL . locationsL) <$> getGame
  LocationWithoutEnemies ->
    filter noEnemiesAtLocation . toList . view (entitiesL . locationsL) <$> getGame
  LocationWithEnemy enemyMatcher -> do
    enemies <- select enemyMatcher
    filterM (fmap (notNull . intersection enemies) . getSet . toId)
      . toList
      . view (entitiesL . locationsL)
      =<< getGame
  LocationWithAsset assetMatcher -> do
    assets <- select assetMatcher
    filterM (fmap (notNull . intersection assets) . getSet . toId)
      . toList
      . view (entitiesL . locationsL)
      =<< getGame
  LocationWithInvestigator whoMatcher -> do
    investigators <- select whoMatcher
    filterM (fmap (notNull . intersection investigators) . getSet . toId)
      . toList
      . view (entitiesL . locationsL)
      =<< getGame
  RevealedLocation -> filter isRevealed . toList . view (entitiesL . locationsL) <$> getGame
  UnrevealedLocation ->
    filter (not . isRevealed) . toList . view (entitiesL . locationsL) <$> getGame
  LocationWithClues gameValueMatcher -> do
    allLocations' <- toList . view (entitiesL . locationsL) <$> getGame
    filterM
      (getCount >=> (`gameValueMatches` gameValueMatcher) . unClueCount)
      allLocations'
  LocationWithDoom gameValueMatcher -> do
    allLocations' <- toList . view (entitiesL . locationsL) <$> getGame
    filterM
      (getCount >=> (`gameValueMatches` gameValueMatcher) . unDoomCount)
      allLocations'
  LocationWithHorror gameValueMatcher -> do
    allLocations' <- toList . view (entitiesL . locationsL) <$> getGame
    filterM
      (getCount >=> (`gameValueMatches` gameValueMatcher) . unHorrorCount)
      allLocations'
  LocationWithMostClues locationMatcher -> do
    matches <- getLocationsMatching locationMatcher
    maxes <$> traverse (traverseToSnd $ (unClueCount <$>) . getCount) matches
  LocationWithoutTreachery matcher -> do
    treacheryIds <- select matcher
    filterM (fmap (none (`elem` treacheryIds)) . getSetList @TreacheryId)
      . toList
      . view (entitiesL . locationsL)
      =<< getGame
  LocationWithTreachery matcher -> do
    treacheryIds <- select matcher
    filterM (fmap (any (`elem` treacheryIds)) . getSetList @TreacheryId)
      . toList
      . view (entitiesL . locationsL)
      =<< getGame
  LocationInDirection direction matcher -> do
    starts <- getLocationsMatching matcher
    matches <- catMaybes <$> traverse (getId . (direction, ) . toId) starts
    filter ((`elem` matches) . toId) . toList . view (entitiesL . locationsL) <$> getGame
  FarthestLocationFromYou matcher -> guardYourLocation $ \start -> do
    matchingLocationIds <- map toId <$> getLocationsMatching matcher
    matches <- getLongestPath start (pure . (`elem` matchingLocationIds))
    filter ((`elem` matches) . toId) . toList . view (entitiesL . locationsL) <$> getGame
  FarthestLocationFromLocation start matcher -> do
    matchingLocationIds <- map toId <$> getLocationsMatching matcher
    matches <- getLongestPath start (pure . (`elem` matchingLocationIds))
    filter ((`elem` matches) . toId) . toList . view (entitiesL . locationsL) <$> getGame
  LocationWithDistanceFrom distance matcher -> do
    iids <- getInvestigatorIds
    candidates <- map toId <$> getLocationsMatching matcher
    distances <- for iids $ \iid -> do
      start <- locationFor iid
      distanceSingletons <$> evalStateT
        (markDistances start (pure . (`elem` candidates)) mempty)
        (LPState (pure start) (singleton start) mempty)
    let matches = HashMap.findWithDefault [] distance (foldr (unionWith (<>)) mempty $ map distanceAggregates distances)
    filter ((`elem` matches) . toId) . toList . view (entitiesL . locationsL) <$> getGame
  FarthestLocationFromAll matcher -> do
    iids <- getInvestigatorIds
    candidates <- map toId <$> getLocationsMatching matcher
    distances <- for iids $ \iid -> do
      start <- locationFor iid
      distanceSingletons <$> evalStateT
        (markDistances start (pure . (`elem` candidates)) mempty)
        (LPState (pure start) (singleton start) mempty)
    let
      overallDistances =
        distanceAggregates $ foldr (unionWith min) mempty distances
      resultIds =
        maybe [] coerce
          . headMay
          . map snd
          . sortOn (Down . fst)
          . mapToList
          $ overallDistances
    traverse getLocation resultIds
  NearestLocationToYou matcher -> guardYourLocation $ \start -> do
    matchingLocationIds <- map toId <$> getLocationsMatching matcher
    matches <- getShortestPath
      start
      (pure . (`elem` matchingLocationIds))
      mempty
    filter ((`elem` matches) . toId) . toList . view (entitiesL . locationsL) <$> getGame
  AccessibleLocation -> guardYourLocation $ \yourLocation -> do
    accessibleLocations <- getSet yourLocation
    filter ((`member` accessibleLocations) . AccessibleLocationId . toId)
      . toList
      . view (entitiesL . locationsL)
      <$> getGame
  ConnectedLocation -> guardYourLocation $ \yourLocation -> do
    connectedLocations <- getSet yourLocation
    filter ((`member` connectedLocations) . ConnectedLocationId . toId)
      . toList
      . view (entitiesL . locationsL)
      <$> getGame
  YourLocation -> guardYourLocation $ fmap pure . getLocation
  NotYourLocation -> guardYourLocation $ \yourLocation ->
    filter ((/= yourLocation) . toId) . toList . view (entitiesL . locationsL) <$> getGame
  LocationWithTrait trait ->
    filterM hasMatchingTrait . toList . view (entitiesL . locationsL) =<< getGame
    where hasMatchingTrait = fmap (trait `member`) . getSet
  LocationWithoutTrait trait ->
    filter missingTrait . toList . view (entitiesL . locationsL) <$> getGame
    where missingTrait = (trait `notMember`) . toTraits
  LocationMatchAll [] -> pure []
  LocationMatchAll (x : xs) -> do
    matches :: HashSet LocationId <-
      foldl' intersection
      <$> (setFromList . map toId <$> getLocationsMatching x)
      <*> traverse (fmap (setFromList . map toId) . getLocationsMatching) xs
    filter ((`member` matches) . toId) . toList . view (entitiesL . locationsL) <$> getGame
  LocationMatchAny [] -> pure []
  LocationMatchAny (x : xs) -> do
    matches :: HashSet LocationId <-
      foldl' union
      <$> (setFromList . map toId <$> getLocationsMatching x)
      <*> traverse (fmap (setFromList . map toId) . getLocationsMatching) xs
    filter ((`member` matches) . toId) . toList . view (entitiesL . locationsL) <$> getGame
  InvestigatableLocation -> toList . view (entitiesL . locationsL) <$> getGame
  AccessibleFrom matcher -> do
    -- returns locations which are accessible from locations found by the matcher
    accessibleLocations <- map AccessibleLocationId <$> getSetList matcher
    filter ((`elem` accessibleLocations) . AccessibleLocationId . toId)
      . toList
      . view (entitiesL . locationsL)
      <$> getGame
  AccessibleTo matcher -> do
    -- returns locations which have access to the locations found by the matcher
    targets <- map AccessibleLocationId <$> getSetList matcher
    locations <- toList . view (entitiesL . locationsL) <$> getGame
    filterM
      (fmap (\locationSet -> all (`member` locationSet) targets) . getSet . toId)
      locations
  -- TODO: to lazy to do these right now
  LocationWithResources _ -> pure []
  -- these can not be queried
  LocationLeavingPlay -> pure []
  SameLocation -> pure []
  ThisLocation -> pure []

guardYourLocation :: (LocationId -> GameT [a]) -> GameT [a]
guardYourLocation body = do
  mlid <- locationFor . view activeInvestigatorIdL =<< getGame
  if mlid /= LocationId (CardId nil) then body mlid else pure []

getAssetsMatching :: AssetMatcher -> GameT [Asset]
getAssetsMatching matcher = do
  assets <- toList . view (entitiesL . assetsL) <$> getGame
  filterMatcher assets matcher
 where
  filterMatcher as = \case
    AnyAsset -> pure as
    AssetWithTitle title -> pure $ filter ((== title) . nameTitle . toName) as
    AssetWithFullTitle title subtitle ->
      pure $ filter ((== Name title (Just subtitle)) . toName) as
    AssetWithId assetId -> pure $ filter ((== assetId) . toId) as
    AssetWithClass role -> filterM (fmap (member role) . getSet . toId) as
    AssetWithDamage -> pure $ filter ((> 0) . fst . getDamage) as
    AssetWithHorror -> pure $ filter ((> 0) . snd . getDamage) as
    AssetWithTrait t -> filterM (fmap (member t) . getSet . toId) as
    AssetInSlot slot -> pure $ filter (elem slot . slotsOf) as
    AssetCanLeavePlayByNormalMeans -> pure $ filter canBeDiscarded as
    AssetControlledBy investigatorMatcher -> do
      iids <- selectList investigatorMatcher
      pure $ filter (maybe False (`elem` iids) . assetController . toAttrs) as
    AssetAtLocation lid -> filterM (fmap (== Just lid) . getId) as
    AssetOneOf ms -> nub . concat <$> traverse (filterMatcher as) ms
    AssetNonStory -> pure $ filter (not . assetIsStory . toAttrs) as
    AssetIs cardCode -> pure $ filter ((== cardCode) . toCardCode) as
    AssetCardMatch cardMatcher ->
      pure $ filter ((`cardMatch` cardMatcher) . toCard) as
    DiscardableAsset -> pure $ filter canBeDiscarded as
    EnemyAsset eid -> pure $ filter ((== Just eid) . assetEnemy . toAttrs) as
    AssetAt locationMatcher -> do
      locations <- map toId <$> getLocationsMatching locationMatcher
      pure $ filter (maybe False (`elem` locations) . assetLocation . toAttrs) as
    AssetReady -> pure $ filter (not . isExhausted) as
    M.AssetExhausted -> pure $ filter isExhausted as
    AssetWithoutModifier modifierType -> flip filterM as $ \a -> do
      modifiers' <- getModifiers (toSource a) (toTarget a)
      pure $ modifierType `notElem` modifiers'
    AssetWithModifier modifierType -> flip filterM as $ \a -> do
      modifiers' <- getModifiers (toSource a) (toTarget a)
      pure $ modifierType `elem` modifiers'
    AssetMatches ms -> foldM filterMatcher as ms
    AssetWithUseType uType -> filterM
      (fmap ((> 0) . unStartingUsesCount) . getCount . (, uType) . toId)
      as
    AssetWithFewestClues assetMatcher -> do
      matches <- getAssetsMatching assetMatcher
      mins <$> traverse (traverseToSnd $ (unClueCount <$>) . getCount) matches
    AssetWithUses uType ->
      filterM (fmap ((> 0) . unUsesCount) . getCount . (, uType) . toId) as
    AssetCanBeAssignedDamageBy iid -> do
      investigatorAssets <- filterMatcher
        as
        (AssetControlledBy $ InvestigatorWithId iid)
      let otherAssets = filter (`notElem` investigatorAssets) as
      otherDamageableAssets <-
        map fst
        . filter (elem CanBeAssignedDamage . snd)
        <$> traverse
              (traverseToSnd $ getModifiers (InvestigatorSource iid) . toTarget)
              otherAssets
      pure $ filter
        isHealthDamageable
        (investigatorAssets <> otherDamageableAssets)
    AssetCanBeAssignedHorrorBy iid -> do
      investigatorAssets <- filterMatcher
        as
        (AssetControlledBy $ InvestigatorWithId iid)
      let otherAssets = filter (`notElem` investigatorAssets) as
      otherDamageableAssets <-
        map fst
        . filter (elem CanBeAssignedDamage . snd)
        <$> traverse
              (traverseToSnd $ getModifiers (InvestigatorSource iid) . toTarget)
              otherAssets
      pure $ filter
        isSanityDamageable
        (investigatorAssets <> otherDamageableAssets)

getEventsMatching :: EventMatcher -> GameT [Event]
getEventsMatching matcher = do
  events <- toList . view (entitiesL . eventsL) <$> getGame
  filterMatcher events matcher
 where
  filterMatcher as = \case
    EventWithTitle title -> pure $ filter ((== title) . nameTitle . toName) as
    EventWithFullTitle title subtitle ->
      pure $ filter ((== Name title (Just subtitle)) . toName) as
    EventWithId eventId -> pure $ filter ((== eventId) . toId) as
    EventWithClass role -> filterM (fmap (member role) . getSet . toId) as
    EventWithTrait t -> filterM (fmap (member t) . getSet . toId) as
    EventControlledBy investigatorMatcher -> do
      iids <- selectList investigatorMatcher
      pure $ filter ((`elem` iids) . ownerOfEvent) as
    EventReady -> pure $ filter (not . eventExhausted . toAttrs) as
    EventMatches ms -> foldM filterMatcher as ms

getSkillsMatching :: SkillMatcher -> GameT [Skill]
getSkillsMatching matcher = do
  skills <- toList . view (entitiesL . skillsL) <$> getGame
  filterMatcher skills matcher
 where
  filterMatcher as = \case
    SkillWithTitle title -> pure $ filter ((== title) . nameTitle . toName) as
    SkillWithFullTitle title subtitle ->
      pure $ filter ((== Name title (Just subtitle)) . toName) as
    SkillWithId skillId -> pure $ filter ((== skillId) . toId) as
    SkillWithClass role -> filterM (fmap (member role) . getSet . toId) as
    SkillWithTrait t -> filterM (fmap (member t) . getSet . toId) as
    SkillControlledBy investigatorMatcher -> do
      iids <- selectList investigatorMatcher
      pure $ filter ((`elem` iids) . ownerOfSkill) as
    SkillMatches ms -> foldM filterMatcher as ms
    AnySkill -> pure as
    YourSkill -> do
      iid <- view activeInvestigatorIdL <$> getGame
      pure $ filter ((== iid) . ownerOfSkill) as

getSkill :: SkillId -> GameT Skill
getSkill sid =
  fromJustNote missingSkill . preview (entitiesL . skillsL . ix sid) <$> getGame
  where missingSkill = "Unknown skill: " <> show sid

getEnemy :: EnemyId -> GameT Enemy
getEnemy eid =
  fromJustNote missingEnemy . preview (entitiesL . enemiesL . ix eid) <$> getGame
  where missingEnemy = "Unknown enemy: " <> show eid

getEnemyMatching :: EnemyMatcher -> GameT (Maybe Enemy)
getEnemyMatching = (listToMaybe <$>) . getEnemiesMatching

getEnemiesMatching
  :: EnemyMatcher
  -> GameT [Enemy]
getEnemiesMatching matcher = do
  allGameEnemies <- toList . view (entitiesL . enemiesL) <$> getGame
  filterM (enemyMatcherFilter matcher) allGameEnemies

enemyMatcherFilter :: EnemyMatcher -> Enemy -> GameT Bool
enemyMatcherFilter = \case
  NotEnemy m -> fmap not . enemyMatcherFilter m
  EnemyWithTitle title -> pure . (== title) . nameTitle . toName
  EnemyWithFullTitle title subtitle ->
    pure . (== Name title (Just subtitle)) . toName
  EnemyWithId enemyId -> pure . (== enemyId) . toId
  NonEliteEnemy -> fmap (notElem Elite) . getSet . toId
  EnemyMatchAll ms -> \enemy -> allM (`enemyMatcherFilter` enemy) ms
  EnemyOneOf ms -> \enemy -> anyM (`enemyMatcherFilter` enemy) ms
  EnemyWithTrait t -> fmap (member t) . getSet . toId
  EnemyWithoutTrait t -> fmap (notMember t) . getSet . toId
  EnemyWithKeyword k -> fmap (elem k) . getSet . toId
  EnemyWithClues gameValueMatcher ->
    getCount >=> (`gameValueMatches` gameValueMatcher) . unClueCount
  EnemyWithDoom gameValueMatcher ->
    getCount >=> (`gameValueMatches` gameValueMatcher) . unDoomCount
  EnemyWithDamage gameValueMatcher ->
    (`gameValueMatches` gameValueMatcher) . fst . getDamage
  ExhaustedEnemy -> pure . isExhausted
  ReadyEnemy -> pure . not . isExhausted
  AnyEnemy -> pure . const True
  EnemyIs cardCode -> pure . (== cardCode) . toCardCode
  NonWeaknessEnemy -> pure . isNothing . cdCardSubType . toCardDef
  EnemyIsEngagedWith investigatorMatcher -> \enemy -> do
    iids <-
      setFromList . map toId <$> getInvestigatorsMatching investigatorMatcher
    notNull . intersection iids <$> getSet (toId enemy)
  EnemyEngagedWithYou -> \enemy -> do
    iid <- view activeInvestigatorIdL <$> getGame
    member iid <$> getSet (toId enemy)
  EnemyNotEngagedWithYou -> \enemy -> do
    iid <- view activeInvestigatorIdL <$> getGame
    notMember iid <$> getSet (toId enemy)
  EnemyWithMostRemainingHealth enemyMatcher -> \enemy -> do
    matches <- getEnemiesMatching enemyMatcher
    elem enemy . maxes <$> traverse (traverseToSnd remainingHealth) matches
  EnemyWithoutModifier modifier -> \enemy ->
    notElem modifier <$> getModifiers (toSource enemy) (toTarget enemy)
  UnengagedEnemy -> \enemy -> null <$> getSet @InvestigatorId (toId enemy)
  UniqueEnemy -> pure . isUnique
  MovingEnemy ->
    \enemy -> (== Just (toId enemy)) . view enemyMovingL <$> getGame
  M.EnemyAt locationMatcher -> \enemy -> case getEnemyLocation enemy of
    Nothing -> pure False
    Just loc -> member loc <$> select locationMatcher
  CanFightEnemy -> \enemy -> do
    iid <- view activeInvestigatorIdL <$> getGame
    modifiers' <- getModifiers (toSource enemy) (InvestigatorTarget iid)
    let
      enemyFilters = mapMaybe
        (\case
          CannotFight m -> Just m
          _ -> Nothing
        )
        modifiers'
      window = Window Timing.When Window.NonFast
    excluded <- if null enemyFilters
      then pure False
      else member (toId enemy) <$> select (mconcat enemyFilters)
    if excluded
      then pure False
      else anyM
        (andM . sequence
          [ pure . (`abilityIs` Action.Fight)
          , -- Because ChooseFightEnemy happens after taking a fight action we
            -- need to decrement the action cost
            getCanPerformAbility iid (InvestigatorSource iid) window
            . (`applyAbilityModifiers` [ActionCostModifier (-1)])
          ]
        )
        (getAbilities enemy)
  CanEvadeEnemy -> \enemy -> do
    iid <- view activeInvestigatorIdL <$> getGame
    let window = Window Timing.When Window.NonFast
    anyM
      (andM . sequence
        [ pure . (`abilityIs` Action.Evade)
        , getCanPerformAbility iid (InvestigatorSource iid) window
        ]
      )
      (getAbilities enemy)
  CanEngageEnemy -> \enemy -> do
    iid <- view activeInvestigatorIdL <$> getGame
    let window = Window Timing.When Window.NonFast
    anyM
      (andM . sequence
        [ pure . (`abilityIs` Action.Engage)
        , getCanPerformAbility iid (InvestigatorSource iid) window
        ]
      )
      (getAbilities enemy)
  NearestEnemy matcher' -> \enemy -> do
    matchingEnemyIds <- map toId <$> getEnemiesMatching matcher'
    matches <- guardYourLocation $ \start -> do
      getShortestPath
        start
        (fmap (any (`elem` matchingEnemyIds)) . getSet)
        mempty
    if null matches
      then pure $ toId enemy `elem` matchingEnemyIds
      else pure $ maybe False (`elem` matches) (getEnemyLocation enemy)

getAct :: ActId -> GameT Act
getAct aid = fromJustNote missingAct . preview (entitiesL . actsL . ix aid) <$> getGame
  where missingAct = "Unknown act: " <> show aid

getAgenda :: AgendaId -> GameT Agenda
getAgenda aid =
  fromJustNote missingAgenda . preview (entitiesL . agendasL . ix aid) <$> getGame
  where missingAgenda = "Unknown agenda: " <> show aid

getAsset :: AssetId -> GameT Asset
getAsset aid =
  fromJustNote missingAsset . preview (entitiesL . assetsL . ix aid) <$> getGame
  where missingAsset = "Unknown asset: " <> show aid

getTreachery :: TreacheryId -> GameT Treachery
getTreachery tid =
  fromJustNote missingTreachery . preview (entitiesL . treacheriesL . ix tid) <$> getGame
  where missingTreachery = "Unknown treachery: " <> show tid

getEvent :: EventId -> GameT Event
getEvent eid =
  fromJustNote missingEvent . preview (entitiesL . eventsL . ix eid) <$> getGame
  where missingEvent = "Unknown event: " <> show eid

getEffect :: EffectId -> GameT Effect
getEffect eid =
  fromJustNote missingEffect . preview (entitiesL . effectsL . ix eid) <$> getGame
  where missingEffect = "Unknown effect: " <> show eid

instance Projection LocationAttrs where
  field f lid = do
    l <- getLocation lid
    case f of
      LocationClues -> pure . locationClues $ toAttrs l

instance Projection AssetAttrs where
  field f aid = do
    a <- getAsset aid
    case f of
      AssetDamage -> pure . assetHealthDamage $ toAttrs a
      AssetHorror -> pure . assetSanityDamage $ toAttrs a
      AssetExhausted -> pure . assetExhausted $ toAttrs a

instance Projection ActAttrs where
  field f aid = do
    l <- getAct aid
    case f of
      ActSequence -> pure . actSequence $ toAttrs l

instance Projection EnemyAttrs where
  field f eid = do
    e <- getEnemy eid
    case f of
      EnemyDoom -> pure . enemyDoom $ toAttrs e
      EnemyEvade -> pure . enemyEvade $ toAttrs e

instance Projection InvestigatorAttrs where
  field f iid = do
    i <- getInvestigator iid
    case f of
      InvestigatorRemainingActions -> pure . investigatorRemainingActions $ toAttrs i
      InvestigatorLocation -> pure . Just . investigatorLocation $ toAttrs i
      InvestigatorHorror -> pure . investigatorSanityDamage $ toAttrs i
      InvestigatorResources -> pure . investigatorResources $ toAttrs i
      InvestigatorHand -> pure . investigatorHand $ toAttrs i
      -- NOTE: For Abilities do not for get inhand, indiscard, insearch

instance Query AssetMatcher where
  select = fmap (setFromList . map toId) . getAssetsMatching

instance Query EventMatcher where
  select = fmap (setFromList . map toId) . getEventsMatching

instance Query LocationMatcher where
  select = fmap (setFromList . map toId) . getLocationsMatching

instance Query EnemyMatcher where
  select = fmap (setFromList . map toId) . getEnemiesMatching

instance Query InvestigatorMatcher where
  select = fmap (setFromList . map toId) . getInvestigatorsMatching

instance Query PreyMatcher where
  select = \case
    Prey matcher -> select matcher
    OnlyPrey matcher -> select matcher
    BearerOf enemyId -> do
      enemy <- getEnemy enemyId
      case enemyBearer (toAttrs enemy) of
        Just iid -> select $ InvestigatorWithId iid
        Nothing -> error "Invalid bearer situation"

instance Query ExtendedCardMatcher where
  select matcher = do
    investigatorIds <- getInvestigatorIds
    handCards <- map unHandCard . concat <$> traverse getList investigatorIds
    deckCards <-
      map (PlayerCard . unDeckCard)
      . concat
      <$> traverse getList investigatorIds
    discards <- getDiscards investigatorIds
    setAsideCards <- map unSetAsideCard <$> getList ()
    victoryDisplayCards <- map unVictoryDisplayCard <$> getSetList ()
    underScenarioReferenceCards <- map unUnderScenarioReferenceCard
      <$> getList ()
    underneathCards <-
      map unUnderneathCard . concat <$> traverse getList investigatorIds
    filterM
      (`matches` matcher)
      (handCards
      <> deckCards
      <> underneathCards
      <> underScenarioReferenceCards
      <> discards
      <> setAsideCards
      <> victoryDisplayCards
      )
   where
    getDiscards iids =
      map PlayerCard
        . concat
        <$> traverse (fmap discardOf . getInvestigator) iids
    matches c = \case
      SetAsideCardMatch matcher' -> do
        cards <- map unSetAsideCard <$> getList ()
        pure $ c `elem` filter (`cardMatch` matcher') cards
      UnderScenarioReferenceMatch matcher' -> do
        cards <- map unUnderScenarioReferenceCard <$> getList ()
        pure $ c `elem` filter (`cardMatch` matcher') cards
      VictoryDisplayCardMatch matcher' -> do
        cards <- map unVictoryDisplayCard <$> getSetList ()
        pure $ c `elem` filter (`cardMatch` matcher') cards
      BasicCardMatch cm -> pure $ cardMatch c cm
      InHandOf who -> do
        iids <- selectList who
        cards <- map unHandCard . concat <$> traverse getList iids
        pure $ c `elem` cards
      TopOfDeckOf who -> do
        iids <- selectList who
        cards <-
          map (PlayerCard . unDeckCard)
          . concatMap (take 1)
          <$> traverse getList iids
        pure $ c `elem` cards
      EligibleForCurrentSkillTest -> do
        mSkillTest <- getSkillTest
        case mSkillTest of
          Nothing -> pure False
          Just st -> pure
            (SkillWild
            `elem` cdSkills (toCardDef c)
            || skillTestSkillType st
            `elem` cdSkills (toCardDef c)
            || (null (cdSkills $ toCardDef c) && toCardType c == SkillType)
            )
      InDiscardOf who -> do
        iids <- selectList who
        discards <- getDiscards iids
        pure $ c `elem` discards
      CardIsBeneathInvestigator who -> do
        iids <- getSetList @InvestigatorId who
        cards <- map unUnderneathCard . concat <$> traverse getList iids
        pure $ c `elem` cards
      ExtendedCardWithOneOf ms -> anyM (matches c) ms
      ExtendedCardMatches ms -> allM (matches c) ms

setScenario :: Scenario -> GameMode -> GameMode
setScenario c (This a) = These a c
setScenario c (That _) = That c
setScenario c (These a _) = These a c

instance HasTokenValue () where
  getTokenValue iid token _ = do
    mScenario <- modeScenario . view modeL <$> getGame
    case mScenario of
      Just scenario -> getTokenValue iid token scenario
      Nothing -> error "missing scenario"

instance HasTokenValue InvestigatorId where
  getTokenValue iid token iid' = do
    investigator <- getInvestigator iid'
    getTokenValue iid token investigator

instance HasModifiersFor () where
  getModifiersFor source target _ = do
    g <- getGame
    allModifiers' <- concat <$> sequence
      [ getModifiersFor source target (g ^. entitiesL)
      , case target of
          InvestigatorTarget i -> maybe (pure []) (getModifiersFor source (InvestigatorHandTarget i)) (g ^. inHandEntitiesL . at i)
          _ -> pure []
      , case target of
          InvestigatorTarget i -> maybe (pure []) (getModifiersFor source (InvestigatorDiscardTarget i)) (g ^. inDiscardEntitiesL . at i)
          _ -> pure []
      , maybe (pure []) (getModifiersFor source target) (g ^. skillTestL)
      , maybe (pure []) (getModifiersFor source target) (modeScenario $ g ^. modeL)
      ]
    traits <- getSet target
    let
      applyTraitRestrictedModifiers m = case modifierType m of
        TraitRestrictedModifier trait modifierType' ->
          m { modifierType = modifierType' } <$ guard (trait `member` traits)
        _ -> Just m
      allModifiers = mapMaybe applyTraitRestrictedModifiers allModifiers'
    pure $ if any ((== Blank) . modifierType) allModifiers
      then filter ((/= targetToSource target) . modifierSource) allModifiers
      else allModifiers

instance HasModifiersFor Entities where
  getModifiersFor source target e = concat <$> sequence
    [ concat
      <$> traverse (getModifiersFor source target) (e ^. enemiesL . to toList)
    , concat
      <$> traverse (getModifiersFor source target) (e ^. assetsL . to toList)
    , concat
      <$> traverse (getModifiersFor source target) (e ^. agendasL . to toList)
    , concat
      <$> traverse (getModifiersFor source target) (e ^. actsL . to toList)
    , concat
      <$> traverse (getModifiersFor source target) (e ^. locationsL . to toList)
    , concat
      <$> traverse (getModifiersFor source target) (e ^. effectsL . to toList)
    , concat
      <$> traverse (getModifiersFor source target) (e ^. eventsL . to toList)
    , concat
      <$> traverse (getModifiersFor source target) (e ^. skillsL . to toList)
    , concat <$> traverse
      (getModifiersFor source target)
      (e ^. treacheriesL . to toList)
    , concat <$> traverse
      (getModifiersFor source target)
      (e ^. investigatorsL . to toList)
    ]

-- the results will have the initial location at 0, we need to drop
-- this otherwise this will only ever return the current location
getShortestPath
  :: LocationId
  -> (LocationId -> GameT Bool)
  -> HashMap LocationId [LocationId]
  -> GameT [LocationId]
getShortestPath !initialLocation !target !extraConnectionsMap = do
  let
    !state' = LPState (pure initialLocation) (singleton initialLocation) mempty
  !result <- evalStateT
    (markDistances initialLocation target extraConnectionsMap)
    state'
  pure
    $ fromMaybe []
    . headMay
    . drop 1
    . map snd
    . sortOn fst
    . mapToList
    $ result

data LPState = LPState
  { _lpSearchQueue :: Seq LocationId
  , _lpVisistedLocations :: HashSet LocationId
  , _lpParents :: HashMap LocationId LocationId
  }

getLongestPath
  :: LocationId
  -> (LocationId -> GameT Bool)
  -> GameT [LocationId]
getLongestPath !initialLocation !target = do
  let
    !state' = LPState (pure initialLocation) (singleton initialLocation) mempty
  !result <- evalStateT (markDistances initialLocation target mempty) state'
  pure
    $ fromMaybe []
    . headMay
    . map snd
    . sortOn (Down . fst)
    . mapToList
    $ result

markDistances
  :: HasGame m
  => LocationId
  -> (LocationId -> GameT Bool)
  -> HashMap LocationId [LocationId]
  -> StateT LPState m (HashMap Int [LocationId])
markDistances initialLocation target extraConnectionsMap = do
  LPState searchQueue visitedSet parentsMap <- get
  if Seq.null searchQueue
    then do
      result <- lift $ getDistances parentsMap
      pure $ insertWith (<>) 0 [initialLocation] result
    else do
      let
        nextLoc = Seq.index searchQueue 0
        newVisitedSet = insertSet nextLoc visitedSet
        extraConnections = findWithDefault [] nextLoc extraConnectionsMap
      adjacentCells <-
        nub
        . (<> extraConnections)
        . map unConnectedLocationId
        <$> getSetList nextLoc
      let
        unvisitedNextCells = filter (`notMember` visitedSet) adjacentCells
        newSearchQueue =
          foldr (flip (Seq.|>)) (Seq.drop 1 searchQueue) unvisitedNextCells
        newParentsMap = foldr
          (\loc map' -> insertWith (\_ b -> b) loc nextLoc map')
          parentsMap
          unvisitedNextCells
      put (LPState newSearchQueue newVisitedSet newParentsMap)
      markDistances initialLocation target extraConnectionsMap
 where
  getDistances map' = do
    locationIds <- filterM target (keys map')
    pure $ foldr
      (\locationId distanceMap ->
        insertWith (<>) (getDistance map' locationId) [locationId] distanceMap
      )
      mempty
      locationIds
  getDistance map' lid = length $ unwindPath map' [lid]
  unwindPath parentsMap currentPath =
    case lookup (fromJustNote "failed bfs" $ headMay currentPath) parentsMap of
      Nothing -> fromJustNote "failed bfs on tail" $ tailMay currentPath
      Just parent -> unwindPath parentsMap (parent : currentPath)

distanceSingletons :: HashMap Int [LocationId] -> HashMap LocationId Int
distanceSingletons hmap = foldr
  (\(n, lids) hmap' -> unions (hmap' : map (`singletonMap` n) lids))
  mempty
  (mapToList hmap)

distanceAggregates :: HashMap LocationId Int -> HashMap Int [LocationId]
distanceAggregates hmap = unionsWith (<>) (map convert $ mapToList hmap)
  where convert = uncurry singletonMap . second pure . swap

instance Query AgendaMatcher where
  select = fmap (setFromList . map toId) . getAgendasMatching

instance Query ActMatcher where
  select = fmap (setFromList . map toId) . getActsMatching

instance Query RemainingActMatcher where
  select = fmap (setFromList . map toCardCode) . getRemainingActsMatching

instance Query AbilityMatcher where
  select = fmap setFromList . getAbilitiesMatching

instance Query SkillMatcher where
  select = fmap (setFromList . map toId) . getSkillsMatching

instance Query TreacheryMatcher where
  select = fmap (setFromList . map toId) . getTreacheriesMatching

-- wait what?
instance Query CardMatcher where
  select _ = pure mempty

instance Query CampaignMatcher where
  select = fmap (setFromList . map toId) . getCampaignsMatching

instance Query EffectMatcher where
  select = fmap (setFromList . map toId) . getEffectsMatching

instance Query ScenarioMatcher where
  select = fmap (setFromList . map toId) . getScenariosMatching

instance Projection AgendaAttrs where
  field fld aid = do
    a <- getAgenda aid
    let AgendaAttrs {..} = toAttrs a
    case fld of
      AgendaSequence -> pure agendaSequence
      AgendaDoom -> pure agendaDoom
      AgendaAbilities -> pure $ getAbilities a

instance Projection CampaignAttrs where
  field fld _ = do
    c <- fromJustNote "impossible" <$> getCampaign
    let CampaignAttrs {..} = toAttrs c
    case fld of
      CampaignCompletedSteps -> pure campaignCompletedSteps
      CampaignStoryCards -> pure campaignStoryCards
      CampaignCampaignLog -> pure campaignLog

instance Projection EffectAttrs where
  field fld eid = do
    e <- getEffect eid
    case fld of
      EffectAbilities -> pure $ getAbilities e

instance Projection EventAttrs where
  field fld eid = do
    e <- getEvent eid
    let attrs@EventAttrs {..} = toAttrs e
        cdef = toCardDef attrs
    case fld of
      EventAttachedTarget -> pure eventAttachedTarget
      EventTraits -> pure $ cdCardTraits cdef
      EventAbilities -> pure $ getAbilities e
      EventOwner -> pure eventOwner
      EventCard -> pure $ lookupCard eventCardCode (unEventId eid)

instance Projection ScenarioAttrs where
  field fld _ = do
    s <- fromJustNote "impossible" <$> getScenario
    let ScenarioAttrs {..} = toAttrs s
    case fld of
      ScenarioCardsUnderActDeck -> pure scenarioCardsUnderActDeck
      ScenarioCardsUnderAgendaDeck -> pure scenarioCardsUnderAgendaDeck
      ScenarioDiscard -> pure scenarioDiscard
      ScenarioDifficulty -> pure scenarioDifficulty
      ScenarioDecks -> pure scenarioDecks
      ScenarioVictoryDisplay -> pure scenarioVictoryDisplay
      ScenarioRemembered -> pure scenarioLog
      ScenarioStandaloneCampaignLog -> pure scenarioStandaloneCampaignLog
      ScenarioResignedCardCodes -> pure scenarioResignedCardCodes
      ScenarioChaosBag -> pure scenarioChaosBag
      ScenarioSetAsideCards -> pure scenarioSetAsideCards
      ScenarioName -> pure scenarioName
      ScenarioStoryCards -> pure scenarioStoryCards

instance Projection SkillAttrs where
  field fld sid = do
    s <- getSkill sid
    let attrs@SkillAttrs {..} = toAttrs s
        cdef = toCardDef attrs
    case fld of
      SkillTraits -> pure $ cdCardTraits cdef
      SkillCard -> pure $ lookupCard skillCardCode (unSkillId sid)

instance Projection TreacheryAttrs where
  field fld tid = do
    t <- getTreachery tid
    let attrs@TreacheryAttrs {..} = toAttrs t
        cdef = toCardDef attrs
    case fld of
      TreacheryClues -> pure treacheryClues
      TreacheryResources -> pure treacheryResources
      TreacheryDoom -> pure treacheryDoom
      TreacheryAttachedTarget -> pure treacheryAttachedTarget
      TreacheryTraits -> pure $ cdCardTraits cdef
      TreacheryKeywords -> pure $ cdKeywords cdef
      TreacheryAbilities -> pure $ getAbilities t
      TreacheryCardDef -> pure cdef
      TreacheryCard -> pure $ lookupCard treacheryCardCode (unTreacheryId tid)

instance {-# OVERLAPPABLE #-} MonadReader Game m => HasGame m where
  getGame = ask

gameGetDistance :: Game -> LocationId -> LocationId -> Maybe Distance
gameGetDistance g start fin = runIdentity $ flip runReaderT g $ do
  let !state' = LPState (pure start) (singleton start) mempty
  result <- evalStateT (markDistances start (pure . (== fin)) mempty) state'
  pure $ fmap Distance . headMay . drop 1 . map fst . sortOn fst . mapToList $ result

runMessages
  :: ( MonadIO m
     , HasGameRef env
     , HasStdGen env
     , HasQueue env
     , MonadReader env m
     , HasGameLogger env
     )
  => Maybe (Message -> IO ())
  -> m ()
runMessages mLogger = do
  gameRef <- view gameRefL
  g <- liftIO $ readIORef gameRef

  queueRef <- view messageQueue

  liftIO $ whenM
    ((== Just "2") <$> lookupEnv "DEBUG")
    (readIORef queueRef >>= pPrint >> putStrLn "\n")

  if g ^. gameStateL /= IsActive
    then toGameEnv >>= flip
      runGameEnvT
      (toExternalGame g mempty >>= atomicWriteIORef gameRef)
    else do
      mmsg <- popMessage
      case mmsg of
        Nothing -> case gamePhase g of
          CampaignPhase -> pure ()
          ResolutionPhase -> pure ()
          MythosPhase -> pure ()
          EnemyPhase -> pure ()
          UpkeepPhase -> pure ()
          InvestigationPhase -> do
            gameEnv <- toGameEnv
            mTurnInvestigator <- runGameEnvT gameEnv $ maybe (pure Nothing) (fmap Just . getInvestigator) =<< selectOne TurnInvestigator
            if maybe
                True
                (or . sequence [investigatorEndedTurn, investigatorResigned, investigatorDefeated] . toAttrs)
                mTurnInvestigator
              then do
                playingInvestigators <- runGameEnvT gameEnv $
                  filterM
                  (fmap
                      (not
                      . (or . sequence [investigatorEndedTurn, investigatorResigned, investigatorDefeated] . toAttrs
                        )
                      )
                  . getInvestigator
                  )
                  (gamePlayerOrder g)
                case playingInvestigators of
                  [] -> do
                    pushEnd EndInvestigation
                    runMessages mLogger
                  [x] -> do
                    push (ChoosePlayer x SetTurnPlayer)
                    runMessages mLogger
                  xs -> do
                    push
                      (chooseOne
                        (g ^. leadInvestigatorIdL)
                        [ ChoosePlayer iid SetTurnPlayer | iid <- xs ]
                      )
                    runMessages mLogger
              else do
                let
                  turnPlayer = fromJustNote "verified above" mTurnInvestigator
                pushAllEnd [PlayerWindow (toId turnPlayer) [] False]
                  >> runMessages mLogger
        Just msg -> do
          liftIO $ whenM
            ((== Just "1") <$> lookupEnv "DEBUG")
            (pPrint msg >> putStrLn "\n")

          liftIO $ maybe (pure ()) ($ msg) mLogger
          case msg of
            Ask iid q -> do
              push $ SetActiveInvestigator $ g ^. activeInvestigatorIdL
              toGameEnv >>= flip
                runGameEnvT
                (toExternalGame
                    (g & activeInvestigatorIdL .~ iid)
                    (singletonMap iid q)
                >>= atomicWriteIORef gameRef
                )
            AskMap askMap -> do
              toGameEnv >>= flip
                runGameEnvT
                (toExternalGame g askMap >>= atomicWriteIORef gameRef)
            _ -> do
              -- Hidden Library handling
              -- > While an enemy is moving, Hidden Library gains the Passageway trait.
              -- Therefor we must track the "while" aspect
              let
                g' = case msg of
                  HunterMove eid -> g & enemyMovingL ?~ eid
                  WillMoveEnemy eid _ -> g & enemyMovingL ?~ eid
                  _ -> g
              atomicWriteIORef gameRef g'
              g'' <- toGameEnv >>= flip runGameEnvT (runMessage msg g')
              atomicWriteIORef gameRef g''
              runMessages mLogger

runPreGameMessage
  :: Message -> Game -> GameT Game
runPreGameMessage msg g = case msg of
  CheckWindow{} -> do
    push EndCheckWindow
    pure $ g & windowDepthL +~ 1
  -- We want to empty the queue for triggering a resolution
  EndCheckWindow -> pure $ g & windowDepthL -~ 1
  ScenarioResolution _ -> do
    clearQueue
    pure $ g & (skillTestL .~ Nothing) & (skillTestResultsL .~ Nothing)
  _ -> pure g

getActiveInvestigator :: GameT Investigator
getActiveInvestigator = getInvestigator =<< getActiveInvestigatorId

runGameMessage
  :: Message
  -> Game
  -> GameT Game
runGameMessage msg g = case msg of
  Run msgs -> g <$ pushAll msgs
  Label _ msgs -> g <$ pushAll msgs
  TargetLabel _ msgs -> g <$ pushAll msgs
  EvadeLabel _ msgs -> g <$ pushAll msgs
  CardLabel _ msgs -> g <$ pushAll msgs
  Continue _ -> pure g
  EndOfGame mNextCampaignStep -> do
    window <- checkWindows [Window Timing.When Window.EndOfGame]
    push window
    pushEnd (EndOfScenario mNextCampaignStep)
    pure g
  ResetGame ->
    pure
      $ g
      & (entitiesL . locationsL .~ mempty)
      & (entitiesL . enemiesL .~ mempty)
      & (encounterDiscardEntitiesL .~ defaultEntities)
      & (enemiesInVoidL .~ mempty)
      & (entitiesL . assetsL .~ mempty)
      & (skillTestL .~ Nothing)
      & (skillTestResultsL .~ Nothing)
      & (entitiesL . actsL .~ mempty)
      & (entitiesL . agendasL .~ mempty)
      & (entitiesL . treacheriesL .~ mempty)
      & (entitiesL . eventsL .~ mempty)
      & (entitiesL . skillsL .~ mempty)
      & (gameStateL .~ IsActive)
      & (turnPlayerInvestigatorIdL .~ Nothing)
      & (focusedCardsL .~ mempty)
      & (activeCardL .~ Nothing)
      & (playerOrderL .~ (g ^. entitiesL . investigatorsL . to keys))
  StartScenario _ sid -> do
    let
      difficulty = these
        difficultyOf
        difficultyOfScenario
        (const . difficultyOf)
        (g ^. modeL)
      standalone = isNothing $ modeCampaign $ g ^. modeL
    pushAll
      ([ StandaloneSetup | standalone ]
      <> [ ChooseLeadInvestigator
         , SetupInvestigators
         , SetTokensForScenario -- (chaosBagOf campaign')
         , InvestigatorsMulligan
         , Setup
         , EndSetup
         ]
      )
    pure
      $ g
      & (modeL %~ setScenario (lookupScenario sid difficulty))
      & (phaseL .~ InvestigationPhase)
  InvestigatorsMulligan ->
    g <$ pushAll [ InvestigatorMulligan iid | iid <- g ^. playerOrderL ]
  InvestigatorMulligan iid -> pure $ g & activeInvestigatorIdL .~ iid
  Will (MoveFrom _ iid lid) -> do
    window <- checkWindows [Window Timing.When (Window.Leaving iid lid)]
    g <$ push window
  After (MoveFrom _ iid lid) -> do
    window <- checkWindows [Window Timing.After (Window.Leaving iid lid)]
    g <$ push window
  CreateEffect cardCode meffectMetadata source target -> do
    (effectId, effect) <- createEffect cardCode meffectMetadata source target
    push (CreatedEffect effectId meffectMetadata source target)
    pure $ g & entitiesL . effectsL %~ insertMap effectId effect
  CreateTokenValueEffect n source target -> do
    (effectId, effect) <- createTokenValueEffect n source target
    push
      (CreatedEffect
        effectId
        (Just $ EffectModifiers [Modifier source $ TokenValueModifier n])
        source
        target
      )
    pure $ g & entitiesL . effectsL %~ insertMap effectId effect
  CreatePayAbilityCostEffect ability source target windows' -> do
    (effectId, effect) <- createPayForAbilityEffect
      ability
      source
      target
      windows'
    push
      (CreatedEffect
        effectId
        (Just $ EffectAbility (ability, windows'))
        source
        target
      )
    pure $ g & entitiesL . effectsL %~ insertMap effectId effect
  CreateWindowModifierEffect effectWindow effectMetadata source target -> do
    (effectId, effect) <- createWindowModifierEffect
      effectWindow
      effectMetadata
      source
      target
    push (CreatedEffect effectId (Just effectMetadata) source target)
    pure $ g & entitiesL . effectsL %~ insertMap effectId effect
  CreateTokenEffect effectMetadata source token -> do
    (effectId, effect) <- createTokenEffect effectMetadata source token
    push
      (CreatedEffect effectId (Just effectMetadata) source (TokenTarget token))
    pure $ g & entitiesL . effectsL %~ insertMap effectId effect
  DisableEffect effectId -> pure $ g & entitiesL . effectsL %~ deleteMap effectId
  FocusCards cards -> pure $ g & focusedCardsL .~ cards
  UnfocusCards -> pure $ g & focusedCardsL .~ mempty
  FocusTargets targets -> pure $ g & focusedTargetsL .~ targets
  UnfocusTargets -> pure $ g & focusedTargetsL .~ mempty
  FocusTokens tokens -> pure $ g & focusedTokensL <>~ tokens
  UnfocusTokens -> pure $ g & focusedTokensL .~ mempty
  ChooseLeadInvestigator -> if length (g ^. entitiesL . investigatorsL) == 1
    then pure g
    else g <$ push
      (chooseOne
        (g ^. leadInvestigatorIdL)
        [ ChoosePlayer iid SetLeadInvestigator
        | iid <- g ^. entitiesL . investigatorsL . to keys
        ]
      )
  ChoosePlayer iid SetLeadInvestigator -> do
    let allPlayers = view playerOrderL g
    push $ ChoosePlayerOrder (filter (/= iid) allPlayers) [iid]
    pure $ g & leadInvestigatorIdL .~ iid
  ChoosePlayer iid SetTurnPlayer ->
    g <$ pushAll [BeginTurn iid, After (BeginTurn iid)]
  MoveTo _ iid _ -> do
    let
      historyItem = mempty { historyMoved = True }
      turn = isJust $ view turnPlayerInvestigatorIdL g
      setTurnHistory =
        if turn then turnHistoryL %~ insertHistory iid historyItem else id
    pure $ g & (phaseHistoryL %~ insertHistory iid historyItem) & setTurnHistory
  FoundCards cards ->
    pure $ g & foundCardsL .~ cards
  AddFocusedToTopOfDeck _ EncounterDeckTarget cardId ->
    if null (gameFoundCards g)
      then do
        let
          card =
            fromJustNote "missing card"
              $ find ((== cardId) . toCardId) (g ^. focusedCardsL)
              >>= toEncounterCard
          focusedCards = filter ((/= cardId) . toCardId) (g ^. focusedCardsL)
        push $ AddToTopOfEncounterDeck card
        pure $ g & (focusedCardsL .~ focusedCards)
      else do
        let
          card =
            fromJustNote "missing card"
              $ find
                  ((== cardId) . toCardId)
                  (concat . toList $ g ^. foundCardsL)
              >>= toEncounterCard
          foundCards =
            HashMap.map (filter ((/= cardId) . toCardId)) (g ^. foundCardsL)
        push $ AddToTopOfEncounterDeck card
        pure $ g & (foundCardsL .~ foundCards)
  GameOver -> do
    clearQueue
    pure $ g & gameStateL .~ IsOver
  PlaceLocation card -> if isNothing $ g ^. entitiesL . locationsL . at (toLocationId card)
    then do
      let
        lid = toLocationId card
        location = lookupLocation (toCardCode card) lid
      push (PlacedLocation (toName location) (toCardCode card) lid)
      pure $ g & entitiesL . locationsL . at lid ?~ location
    else pure g
  RemoveEnemy eid -> pure $ g & entitiesL . enemiesL %~ deleteMap eid
  When (RemoveLocation lid) -> do
    window <- checkWindows
      [Window Timing.When (Window.LeavePlay $ LocationTarget lid)]
    g <$ push window
  RemoveLocation lid -> do
    treacheryIds <- selectList $ TreacheryAt $ LocationWithId lid
    pushAll $ concatMap (resolve . Discard . TreacheryTarget) treacheryIds
    enemyIds <- selectList $ EnemyAt $ LocationWithId lid
    pushAll $ concatMap (resolve . Discard . EnemyTarget) enemyIds
    eventIds <- selectList $ EventAt $ LocationWithId  lid
    pushAll $ concatMap (resolve . Discard . EventTarget) eventIds
    assetIds <- selectList (AssetAt $ LocationWithId lid)
    pushAll $ concatMap (resolve . Discard . AssetTarget) assetIds
    investigatorIds <- selectList $ InvestigatorAt $ LocationWithId lid
    pushAll $ concatMap
      (resolve . Msg.InvestigatorDefeated (LocationSource lid))
      investigatorIds
    pure $ g & entitiesL . locationsL %~ deleteMap lid
  SpendClues 0 _ -> pure g
  SpendClues n iids -> do
    investigatorsWithClues <- filter ((> 0) . snd) <$> for
      (filter ((`elem` iids) . fst) $ mapToList $ g ^. entitiesL . investigatorsL)
      (\(iid, i) -> (iid,) <$> getSpendableClueCount (toAttrs i))
    case investigatorsWithClues of
      [] -> error "someone needed to spend some clues"
      [(x, _)] -> g <$ push (InvestigatorSpendClues x n)
      xs -> do
        if sum (map snd investigatorsWithClues) == n
          then
            g
              <$ pushAll
                   [ InvestigatorSpendClues iid x
                   | (iid, x) <- investigatorsWithClues
                   ]
          else g <$ pushAll
            [ chooseOne (gameLeadInvestigatorId g)
              $ map ((`InvestigatorSpendClues` 1) . fst) xs
            , SpendClues (n - 1) (map fst investigatorsWithClues)
            ]
  AdvanceCurrentAgenda -> do
    let aids = keys $ g ^. entitiesL . agendasL
    g <$ pushAll [ AdvanceAgenda aid | aid <- aids ]
  ReplaceAgenda aid1 aid2 ->
    pure $ g & entitiesL . agendasL %~ deleteMap aid1 & entitiesL . agendasL %~ insertMap
      aid2
      (lookupAgenda aid2 1)
  ReplaceAct aid1 aid2 ->
    pure $ g & entitiesL . actsL %~ deleteMap aid1 & entitiesL . actsL %~ insertMap
      aid2
      (lookupAct aid2 1)
  AddAct def -> do
    let aid = ActId $ toCardCode def
    pure $ g & entitiesL . actsL . at aid ?~ lookupAct aid 1
  AddAgenda def -> do
    let aid = AgendaId $ toCardCode def
    pure $ g & entitiesL . agendasL . at aid ?~ lookupAgenda aid 1
  CommitCard iid cardId -> do
    investigator' <- getInvestigator iid
    let
      card = fromJustNote "could not find card in hand" $ find
        ((== cardId) . toCardId)
        (investigatorHand (toAttrs investigator') <> map PlayerCard (unDeck . investigatorDeck $ toAttrs investigator'))
    push $ InvestigatorCommittedCard iid card
    case card of
      PlayerCard pc -> case toCardType pc of
        SkillType -> do
          let
            skill = createSkill pc iid
            skillId = toId skill
          push (InvestigatorCommittedSkill iid skillId)
          for_ (skillAdditionalCost $ toAttrs skill) $ \cost -> do
            let ability = abilityEffect skill cost
            push $ CreatePayAbilityCostEffect ability (toSource skill) (InvestigatorTarget iid) []
          pure $ g & entitiesL . skillsL %~ insertMap skillId skill
        _ -> pure g
      _ -> pure g
  SkillTestResults skillValue iconValue tokenValue' skillDifficulty ->
    pure
      $ g
      & skillTestResultsL
      ?~ SkillTestResultsData skillValue iconValue tokenValue' skillDifficulty
  SkillTestEnds _ -> do
    skillPairs <- for (mapToList $ g ^. entitiesL . skillsL) $ \(skillId, skill) -> do
      modifiers' <- getModifiers GameSource (SkillTarget skillId)
      pure $ if ReturnToHandAfterTest `elem` modifiers'
        then (ReturnToHand (skillOwner $ toAttrs skill) (SkillTarget skillId), Nothing)
        else
          ( AddToDiscard
            (skillOwner $ toAttrs skill)
            (lookupPlayerCard (toCardDef skill) (unSkillId skillId))
          , Just skillId
          )
    pushAll $ map fst skillPairs
    let skillsToRemove = mapMaybe snd skillPairs
    pure
      $ g
      & (entitiesL . skillsL %~ HashMap.filterWithKey (\k _ -> k `notElem` skillsToRemove))
      & (skillTestL .~ Nothing)
      & (skillTestResultsL .~ Nothing)
  EndSearch iid _ target cardSources -> do
    when
      (target == EncounterDeckTarget)
      do
        let
          foundKey = \case
            Zone.FromTopOfDeck _ -> Zone.FromDeck
            other -> other
          foundCards = gameFoundCards g
        for_ cardSources $ \(cardSource, returnStrategy) ->
          case returnStrategy of
            PutBackInAnyOrder -> do
              when
                (foundKey cardSource /= Zone.FromDeck)
                (error "Expects a deck")
              push
                (chooseOneAtATime iid $ map
                  (AddFocusedToTopOfDeck iid EncounterDeckTarget . toCardId)
                  (findWithDefault [] Zone.FromDeck foundCards)
                )
            ShuffleBackIn -> do
              when
                (foundKey cardSource /= Zone.FromDeck)
                (error "Expects a deck")
              push
                (ShuffleIntoEncounterDeck
                  (mapMaybe (preview _EncounterCard)
                  $ findWithDefault [] Zone.FromDeck foundCards
                  )
                )
            PutBack -> do
              when
                (foundKey cardSource /= Zone.FromDeck)
                (error "Can not take deck")
              pushAll
                (map (AddFocusedToTopOfDeck iid EncounterDeckTarget . toCardId)
                  (reverse $ mapMaybe (preview _EncounterCard)
                  $ findWithDefault [] Zone.FromDeck foundCards
                  )
                )
    pure g
  ReturnToHand iid (SkillTarget skillId) -> do
    card <- field SkillCard skillId
    push $ AddToHand iid card
    pure $ g & entitiesL . skillsL %~ deleteMap skillId
  ReturnToHand iid (AssetTarget assetId) -> do
    asset <- getAsset assetId
    card <- field AssetCard assetId
    if assetIsStory $ toAttrs asset
      then g <$ push (Discard $ AssetTarget assetId)
      else do
        push $ AddToHand iid card
        pure $ g & entitiesL . assetsL %~ deleteMap assetId
  ReturnToHand iid (EventTarget eventId) -> do
    card <- field EventCard eventId
    push $ AddToHand iid card
    pure $ g & entitiesL . eventsL %~ deleteMap eventId
  After (ShuffleIntoDeck _ (AssetTarget aid)) ->
    pure $ g & entitiesL . assetsL %~ deleteMap aid
  After (ShuffleIntoDeck _ (EventTarget eid)) ->
    pure $ g & entitiesL . eventsL %~ deleteMap eid
  ShuffleIntoDeck iid (TreacheryTarget treacheryId) -> do
    treachery <- getTreachery treacheryId
    case toCard treachery of
      PlayerCard card -> push (ShuffleCardsIntoDeck iid [card])
      EncounterCard _ -> error "Unhandled"
    pure $ g & entitiesL . treacheriesL %~ deleteMap treacheryId
  ShuffleIntoDeck iid (EnemyTarget enemyId) -> do
    -- The Thing That Follows
    card <- field EnemyCard enemyId
    case card of
      PlayerCard pc -> push (ShuffleCardsIntoDeck iid [pc])
      EncounterCard _ -> error "Unhandled"
    pure $ g & entitiesL . enemiesL %~ deleteMap enemyId
  PlayDynamicCard iid cardId n _mtarget False -> do
    investigator' <- getInvestigator iid
    let
      card = fromJustNote "could not find card in hand"
        $ find ((== cardId) . toCardId) (investigatorHand $ toAttrs investigator')
    case card of
      PlayerCard pc -> case toCardType pc of
        PlayerTreacheryType -> error "unhandled"
        AssetType -> do
          let aid = AssetId cardId
            -- asset = fromJustNote
            --   "could not find asset"
            --   (lookup (toCardCode pc) allAssets)
            --   aid
          asset <- runMessage
            (SetOriginalCardCode $ pcOriginalCardCode pc)
            (createAsset pc)
          pushAll
            [ PlayedCard iid card
            , InvestigatorPlayDynamicAsset
              iid
              aid
              n
            , ResolvedCard iid card
            ]
          pure $ g & entitiesL . assetsL %~ insertMap aid asset
        EventType -> do
          event' <- runMessage
            (SetOriginalCardCode $ pcOriginalCardCode pc)
            (createEvent pc iid)
          let eid = toId event'
          pushAll
            [ PlayedCard iid card
            , InvestigatorPlayDynamicEvent iid eid n
            , ResolvedCard iid card
            ]
          pure $ g & entitiesL . eventsL %~ insertMap eid event'
        _ -> pure g
      EncounterCard _ -> pure g
  PlayCard iid cardId mtarget False -> do
    investigator' <- getInvestigator iid
    playableCards <- getPlayableCards
      (toAttrs investigator')
      PaidCost
      [ Window Timing.When (Window.DuringTurn iid)
      , Window Timing.When Window.NonFast
      , Window Timing.When Window.FastPlayerWindow
      ]
    case find ((== cardId) . toCardId) playableCards of
      Nothing -> pure g -- card become unplayable during paying the cost
      Just card -> runGameMessage (PutCardIntoPlay iid card mtarget) g
  PlayFastEvent iid cardId mtarget windows' -> do
    investigator' <- getInvestigator iid
    playableCards <- getPlayableCards (toAttrs investigator') PaidCost windows'
    case find ((== cardId) . toCardId) (playableCards <> investigatorHand (toAttrs investigator')) of
      Nothing -> pure g -- card was discarded before playing
      Just card -> do
        event' <- runMessage
          (SetOriginalCardCode $ toOriginalCardCode card)
          (createEvent card iid)
        let
          eid = toId event'
          zone = if card `elem` investigatorHand (toAttrs investigator')
            then Zone.FromHand
            else Zone.FromDiscard
        pushAll
          [ PayCardCost iid (toCardId card)
          , PlayedCard iid card
          , InvestigatorPlayEvent iid eid mtarget windows' zone
          , ResolvedCard iid card
          ]
        pure $ g & entitiesL . eventsL %~ insertMap eid event'
  PutCardIntoPlay iid card mtarget -> do
    let cardId = toCardId card
    case card of
      PlayerCard pc -> case toCardType pc of
        PlayerTreacheryType -> do
          let
            tid = TreacheryId cardId
            treachery = lookupTreachery (toCardCode pc) iid tid
          pushAll
            $ resolve (Revelation iid (TreacherySource tid))
            <> [UnsetActiveCard]
          pure
            $ g
            & (entitiesL . treacheriesL %~ insertMap tid treachery)
            & (activeCardL ?~ card)
        AssetType -> do
          let aid = AssetId cardId
          asset <- runMessage
            (SetOriginalCardCode $ pcOriginalCardCode pc)
            (createAsset card)
          pushAll
            [ PlayedCard iid card
            , InvestigatorPlayAsset iid aid
            , ResolvedCard iid card
            ]
          pure $ g & entitiesL . assetsL %~ insertMap aid asset
        EventType -> do
          event' <- runMessage
            (SetOriginalCardCode $ pcOriginalCardCode pc)
            (createEvent pc iid)
          investigator' <- getInvestigator iid
          let
            eid = toId event'
            zone = if card `elem` investigatorHand (toAttrs investigator')
              then Zone.FromHand
              else Zone.FromDiscard
          pushAll
            [ PlayedCard iid card
            , InvestigatorPlayEvent iid eid mtarget [] zone
            , ResolvedCard iid card
            ]
          pure $ g & entitiesL . eventsL %~ insertMap eid event'
        _ -> pure g
      EncounterCard _ -> pure g
  DrewPlayerEnemy iid card -> do
    lid <- getJustLocation iid
    let
      enemy = createEnemy card
      eid = toId enemy
    pushAll
      [ SetBearer (toTarget enemy) iid
      , RemoveCardFromHand iid (toCardId card)
      , InvestigatorDrawEnemy iid lid eid
      ]
    pure $ g & entitiesL . enemiesL %~ insertMap eid enemy
  CancelNext msgType -> do
    withQueue_ $ \queue ->
      let
        (before, after) = break ((== Just msgType) . messageType) queue
        remaining = case after of
          [] -> []
          (_ : xs) -> xs
      in before <> remaining
    pure g
  EngageEnemy iid eid False -> do
    push =<< checkWindows [Window Timing.After (Window.EnemyEngaged iid eid)]
    pure g
  EnemyEngageInvestigator eid iid -> do
    push =<< checkWindows [Window Timing.After (Window.EnemyEngaged iid eid)]
    pure g
  SkillTestAsk (Ask iid1 (ChooseOne c1)) -> do
    mNextMessage <- peekMessage
    case mNextMessage of
      Just (SkillTestAsk (Ask iid2 (ChooseOne c2))) -> do
        _ <- popMessage
        push
          (SkillTestAsk
            (AskMap $ mapFromList [(iid1, ChooseOne c1), (iid2, ChooseOne c2)])
          )
      _ -> push (chooseOne iid1 c1)
    pure g
  SkillTestAsk (AskMap askMap) -> do
    mNextMessage <- peekMessage
    case mNextMessage of
      Just (SkillTestAsk (Ask iid2 (ChooseOne c2))) -> do
        _ <- popMessage
        push
          (SkillTestAsk
            (AskMap $ insertWith
              (\(ChooseOne m) (ChooseOne n) -> ChooseOne $ m <> n)
              iid2
              (ChooseOne c2)
              askMap
            )
          )
      _ -> push (AskMap askMap)
    pure g
  AskPlayer (Ask iid1 (ChooseOne c1)) -> do
    mNextMessage <- peekMessage
    case mNextMessage of
      Just (AskPlayer (Ask iid2 (ChooseOne c2))) -> do
        _ <- popMessage
        push
          (AskPlayer
            (AskMap $ mapFromList [(iid1, ChooseOne c1), (iid2, ChooseOne c2)])
          )
      _ -> push (chooseOne iid1 c1)
    pure g
  AskPlayer (AskMap askMap) -> do
    mNextMessage <- peekMessage
    case mNextMessage of
      Just (AskPlayer (Ask iid2 (ChooseOne c2))) -> do
        _ <- popMessage
        push
          (AskPlayer
            (AskMap $ insertWith
              (\(ChooseOne m) (ChooseOne n) -> ChooseOne $ m <> n)
              iid2
              (ChooseOne c2)
              askMap
            )
          )
      _ -> push (AskMap askMap)
    pure g
  EnemyWillAttack iid eid damageStrategy attackType -> do
    modifiers' <- getModifiers (EnemySource eid) (InvestigatorTarget iid)
    traits <- field EnemyTraits eid
    let
      cannotBeAttackedByNonElites = flip any modifiers' $ \case
        CannotBeAttackedByNonElite{} -> True
        _ -> False
      canAttack =
        not cannotBeAttackedByNonElites || (Elite `elem` traits)
    if canAttack
      then do
        mNextMessage <- peekMessage
        case mNextMessage of
          Just (EnemyAttacks as) -> do
            _ <- popMessage
            push (EnemyAttacks (EnemyAttack iid eid damageStrategy attackType : as))
          Just aoo@(CheckAttackOfOpportunity _ _) -> do
            _ <- popMessage
            push msg
            push aoo
          Just (EnemyWillAttack iid2 eid2 damageStrategy2 attackType2) -> do
            _ <- popMessage
            modifiers2' <- getModifiers
              (EnemySource eid2)
              (InvestigatorTarget iid2)
            traits2 <- field EnemyTraits eid2
            let
              cannotBeAttackedByNonElites2 = flip any modifiers2' $ \case
                CannotBeAttackedByNonElite{} -> True
                _ -> False
              canAttack2 =
                not cannotBeAttackedByNonElites2
                  || (Elite `elem` traits2)
            if canAttack2
              then push
                (EnemyAttacks
                  [ EnemyAttack iid eid damageStrategy attackType
                  , EnemyAttack iid2 eid2 damageStrategy2 attackType2
                  ]
                )
              else push (EnemyAttacks [EnemyAttack iid eid damageStrategy attackType])
          _ -> push (EnemyAttack iid eid damageStrategy attackType)
        pure g
      else pure g
  EnemyAttacks as -> do
    mNextMessage <- peekMessage
    case mNextMessage of
      Just (EnemyAttacks as2) -> do
        _ <- popMessage
        push (EnemyAttacks $ as ++ as2)
      Just aoo@(CheckAttackOfOpportunity _ _) -> do
        _ <- popMessage
        push msg
        push aoo
      Just (EnemyWillAttack iid2 eid2 damageStrategy2 attackType2) -> do
        _ <- popMessage
        push (EnemyAttacks (EnemyAttack iid2 eid2 damageStrategy2 attackType2 : as))
      _ -> push (chooseOneAtATime (gameLeadInvestigatorId g) as)
    pure g
  When (AssetDefeated aid) -> do
    defeatedWindow <- checkWindows
      [Window Timing.When (Window.Defeated (AssetSource aid))]
    g <$ push defeatedWindow
  Flipped (AssetSource aid) card | toCardType card /= AssetType ->
    pure $ g & entitiesL . assetsL %~ deleteMap aid
  RemoveFromGame (AssetTarget aid) -> do
    card <- field AssetCard aid
    pure $ g & entitiesL . assetsL %~ deleteMap aid & removedFromPlayL %~ (card :)
  RemoveFromGame (EventTarget eid) -> do
    card <- field EventCard eid
    pure $ g & entitiesL . eventsL %~ deleteMap eid & removedFromPlayL %~ (card :)
  RemovedFromGame card -> pure $ g & removedFromPlayL %~ (card :)
  PlaceEnemyInVoid eid -> do
    withQueue_ $ filter (/= Discard (EnemyTarget eid))
    enemy <- getEnemy eid
    pure $ g & entitiesL . enemiesL %~ deleteMap eid & enemiesInVoidL %~ insertMap eid enemy
  EnemySpawnFromVoid miid lid eid -> do
    pushAll (resolve $ EnemySpawn miid lid eid)
    case lookup eid (g ^. enemiesInVoidL) of
      Just enemy ->
        pure
          $ g
          & (activeCardL .~ Nothing)
          & (focusedCardsL .~ mempty)
          & (enemiesInVoidL %~ deleteMap eid)
          & (entitiesL . enemiesL %~ insertMap eid enemy)
      Nothing -> error "enemy was not in void"
  Discard (SearchedCardTarget cardId) -> do
    investigator' <- getActiveInvestigator
    let
      card = fromJustNote "must exist"
        $ find ((== cardId) . toCardId) $ (g ^. focusedCardsL) <> (concat . HashMap.elems . investigatorFoundCards $ toAttrs investigator')
    case card of
      PlayerCard pc -> do
        pushAll [RemoveCardFromSearch (toId investigator') cardId, AddToDiscard (toId investigator') pc]
        pure $ g & focusedCardsL %~ filter (/= card)
      _ -> error "should not be an option for other cards"
  Discard (ActTarget _) -> pure $ g & entitiesL . actsL .~ mempty
  Discarded (EnemyTarget eid) _ -> do
    enemy <- getEnemy eid
    card <- field EnemyCard eid
    case card of
      PlayerCard pc -> do
        case enemyBearer (toAttrs enemy) of
          Nothing -> push (RemoveFromGame $ EnemyTarget eid)
          -- The Man in the Pallid Mask has not bearer in Curtain Call
          Just iid' -> push (AddToDiscard iid' pc)
      EncounterCard _ -> pure ()
    pure $ g & (entitiesL . enemiesL %~ deleteMap eid)
  AddToVictory (EnemyTarget eid) -> do
    card <- field EnemyCard eid
    windowMsgs <- windows [Window.AddedToVictory card]
    pushAll windowMsgs
    pure g
  AddToVictory (EventTarget eid) -> do
    card <- field EventCard eid
    windowMsgs <- windows [Window.AddedToVictory card]
    pushAll windowMsgs
    pure $ g & (entitiesL . eventsL %~ deleteMap eid) -- we might not want to remove here?
  PlayerWindow iid _ _ -> pure $ g & activeInvestigatorIdL .~ iid
  Begin InvestigationPhase -> do
    investigatorIds <- getInvestigatorIds
    phaseBeginsWindow <- checkWindows
      [ Window Timing.When Window.AnyPhaseBegins
      , Window Timing.When (Window.PhaseBegins EnemyPhase)
      , Window Timing.After Window.AnyPhaseBegins
      , Window Timing.After (Window.PhaseBegins EnemyPhase)
      , Window Timing.When Window.FastPlayerWindow
      ]
    case investigatorIds of
      [] -> error "no investigators"
      [iid] -> pushAll [phaseBeginsWindow, ChoosePlayer iid SetTurnPlayer]
      xs -> pushAll
        [ phaseBeginsWindow
        , chooseOne
          (g ^. leadInvestigatorIdL)
          [ ChoosePlayer iid SetTurnPlayer | iid <- xs ]
        ]
    pure $ g & phaseL .~ InvestigationPhase
  BeginTurn x -> do
    push =<< checkWindows
      [ Window Timing.When (Window.TurnBegins x)
      , Window Timing.After (Window.TurnBegins x)
      ]
    pure $ g & activeInvestigatorIdL .~ x & turnPlayerInvestigatorIdL ?~ x
  ChoosePlayerOrder [x] [] -> do
    pure $ g & playerOrderL .~ [x]
  ChoosePlayerOrder [] (x : xs) -> do
    pure $ g & playerOrderL .~ (x : xs)
  ChoosePlayerOrder [y] (x : xs) -> do
    pure $ g & playerOrderL .~ (x : (xs <> [y]))
  ChoosePlayerOrder investigatorIds orderedInvestigatorIds -> do
    push $ chooseOne
      (gameLeadInvestigatorId g)
      [ ChoosePlayerOrder
          (filter (/= iid) investigatorIds)
          (orderedInvestigatorIds <> [iid])
      | iid <- investigatorIds
      ]
    pure $ g & activeInvestigatorIdL .~ gameLeadInvestigatorId g
  ChooseEndTurn iid -> do
    push =<< checkWindows
      [ Window Timing.When (Window.TurnEnds iid)
      , Window Timing.After (Window.TurnEnds iid)
      ]
    g <$ pushAll (resolve $ EndTurn iid)
  EndTurn _ -> pure $ g & turnHistoryL .~ mempty
  EndPhase -> do
    clearQueue
    case g ^. phaseL of
      MythosPhase -> pushEnd $ Begin InvestigationPhase
      InvestigationPhase -> pushEnd $ Begin EnemyPhase
      EnemyPhase -> pushEnd $ Begin UpkeepPhase
      UpkeepPhase -> pushAllEnd [EndRoundWindow, EndRound]
      ResolutionPhase -> error "should not be called in this situation"
      CampaignPhase -> error "should not be called in this situation"
    pure
      $ g
      & (roundHistoryL %~ (<> view phaseHistoryL g))
      & (phaseHistoryL %~ mempty)
  EndInvestigation -> do
    pushAll . (: [EndPhase]) =<< checkWindows
      [Window Timing.When (Window.PhaseEnds InvestigationPhase)]
    pure
      $ g
      & (phaseHistoryL .~ mempty)
      & (turnPlayerInvestigatorIdL .~ Nothing)
  Begin EnemyPhase -> do
    phaseBeginsWindow <- checkWindows
      [ Window Timing.When Window.AnyPhaseBegins
      , Window Timing.When (Window.PhaseBegins EnemyPhase)
      , Window Timing.After Window.AnyPhaseBegins
      , Window Timing.After (Window.PhaseBegins EnemyPhase)
      ]
    pushAllEnd [phaseBeginsWindow, HuntersMove, EnemiesAttack, EndEnemy]
    pure $ g & phaseL .~ EnemyPhase
  EnemyAttackFromDiscard iid card -> do
    let
      enemy = createEnemy card
      enemyId = toId enemy
    push $ EnemyWillAttack iid enemyId (enemyDamageStrategy $ toAttrs enemy) RegularAttack
    pure $ g & encounterDiscardEntitiesL . enemiesL . at enemyId ?~ enemy
  EndEnemy -> do
    pushAll . (: [EndPhase]) =<< checkWindows
      [Window Timing.When (Window.PhaseEnds EnemyPhase)]
    pure $ g & (phaseHistoryL .~ mempty)
  Begin UpkeepPhase -> do
    phaseBeginsWindow <- checkWindows
      [ Window Timing.When Window.AnyPhaseBegins
      , Window Timing.When (Window.PhaseBegins UpkeepPhase)
      , Window Timing.After Window.AnyPhaseBegins
      , Window Timing.After (Window.PhaseBegins UpkeepPhase)
      ]
    pushAllEnd
      [ phaseBeginsWindow
      , ReadyExhausted
      , AllDrawCardAndResource
      , AllCheckHandSize
      , EndUpkeep
      ]
    pure $ g & phaseL .~ UpkeepPhase
  EndUpkeep -> do
    pushAll . (: [EndPhase]) =<< checkWindows
      [Window Timing.When (Window.PhaseEnds UpkeepPhase)]
    pure
      $ g
      & (phaseHistoryL .~ mempty)
  EndRoundWindow -> do
    endRoundMessage <- checkWindows [Window Timing.When Window.AtEndOfRound]
    g <$ push endRoundMessage
  EndRound -> do
    pushEnd BeginRound
    pure $ g & (roundHistoryL .~ mempty)
  BeginRound -> g <$ pushEnd (Begin MythosPhase)
  Begin MythosPhase -> do
    phaseBeginsWindow <- checkWindows
      [ Window Timing.When Window.AnyPhaseBegins
      , Window Timing.When (Window.PhaseBegins MythosPhase)
      , Window Timing.After Window.AnyPhaseBegins
      , Window Timing.After (Window.PhaseBegins MythosPhase)
      ]
    allDrawWindow <- checkWindows
      [Window Timing.When Window.AllDrawEncounterCard]
    fastWindow <- checkWindows [Window Timing.When Window.FastPlayerWindow]
    modifiers <- getModifiers GameSource (PhaseTarget MythosPhase)
    pushAllEnd
      $ phaseBeginsWindow
      : [ PlaceDoomOnAgenda
        | SkipMythosPhaseStep PlaceDoomOnAgendaStep `notElem` modifiers
        ]
      <> [ AdvanceAgendaIfThresholdSatisfied
         , allDrawWindow
         , AllDrawEncounterCard
         , fastWindow
         , EndMythos
         ]
    pure $ g & phaseL .~ MythosPhase
  AllDrawEncounterCard -> do
    playerIds <- filterM
      (fmap not . isEliminated)
      (view playerOrderL g)
    g <$ pushAll
      ([ chooseOne iid [InvestigatorDrawEncounterCard iid] | iid <- playerIds ]
      <> [SetActiveInvestigator $ g ^. activeInvestigatorIdL]
      )
  EndMythos -> do
    pushAll . (: [EndPhase]) =<< checkWindows
      [Window Timing.When (Window.PhaseEnds MythosPhase)]
    pure $ g & (phaseHistoryL .~ mempty)
  BeginSkillTest iid source target maction skillType difficulty -> do
    availableSkills <- getAvailableSkillsFor skillType iid
    windows' <- windows [Window.InitiatedSkillTest iid maction difficulty]
    case availableSkills of
      [] -> g <$ pushAll
        (windows'
        <> [ BeginSkillTestAfterFast
               iid
               source
               target
               maction
               skillType
               difficulty
           ]
        )
      [_] -> g <$ pushAll
        (windows'
        <> [ BeginSkillTestAfterFast
               iid
               source
               target
               maction
               skillType
               difficulty
           ]
        )
      xs -> g <$ push
        (chooseOne
          iid
          [ Run
              (windows'
              <> [ BeginSkillTestAfterFast
                     iid
                     source
                     target
                     maction
                     skillType'
                     difficulty
                 ]
              )
          | skillType' <- xs
          ]
        )
  BeforeSkillTest iid _ _ -> pure $ g & activeInvestigatorIdL .~ iid
  BeginSkillTestAfterFast iid source target maction skillType difficulty -> do
    windowMsg <- checkWindows [Window Timing.When Window.FastPlayerWindow]
    pushAll [windowMsg, BeforeSkillTest iid skillType difficulty]
    skillValue <- getSkillValue skillType iid
    pure
      $ g
      & (skillTestL
        ?~ initSkillTest
             iid
             source
             target
             maction
             skillType
             skillValue
             difficulty
        )
  CreateStoryAssetAtLocationMatching cardCode locationMatcher -> do
    lid <- selectJust locationMatcher
    g <$ push (CreateStoryAssetAt cardCode lid)
  CreateStoryAssetAt card lid -> do
    let
      asset = createAsset card
      assetId = toId asset
    push $ AttachAsset assetId (LocationTarget lid)
    pure $ g & entitiesL . assetsL . at assetId ?~ asset
  CreateWeaknessInThreatArea card iid -> do
    let
      treachery = createTreachery card iid
      treacheryId = toId treachery
    push (AttachTreachery treacheryId (InvestigatorTarget iid))
    pure $ g & entitiesL . treacheriesL . at treacheryId ?~ treachery
  AttachStoryTreacheryTo card target -> do
    let
      treachery = createTreachery card (g ^. leadInvestigatorIdL)
      treacheryId = toId treachery
    push (AttachTreachery treacheryId target)
    pure $ g & entitiesL . treacheriesL . at treacheryId ?~ treachery
  TakeControlOfSetAsideAsset iid card -> do
    let
      asset = createAsset card
      assetId = toId asset
    pushAll [TakeControlOfAsset iid assetId]
    pure $ g & entitiesL . assetsL . at assetId ?~ asset
  ReplaceInvestigatorAsset iid card -> do
    let
      asset = createAsset card
      assetId = toId asset
    push (ReplacedInvestigatorAsset iid assetId)
    pure $ g & entitiesL . assetsL . at assetId ?~ asset
  When (EnemySpawn _ lid eid) -> do
    windowMsg <- checkWindows [Window Timing.When (Window.EnemySpawns eid lid)]
    g <$ push windowMsg
  After (EnemySpawn _ lid eid) -> do
    windowMsg <- checkWindows [Window Timing.After (Window.EnemySpawns eid lid)]
    g <$ push windowMsg
  SpawnEnemyAt card lid -> do
    let
      enemy = createEnemy card
      eid = toId enemy
    pushAll
      [ Will (EnemySpawn Nothing lid eid)
      , When (EnemySpawn Nothing lid eid)
      , EnemySpawn Nothing lid eid
      ]
    pure $ g & entitiesL . enemiesL . at eid ?~ enemy
  SpawnEnemyAtEngagedWith card lid iid -> do
    let
      enemy = createEnemy card
      eid = toId enemy
    pushAll
      [ Will (EnemySpawn (Just iid) lid eid)
      , When (EnemySpawn (Just iid) lid eid)
      , EnemySpawn (Just iid) lid eid
      ]
    pure $ g & entitiesL . enemiesL . at eid ?~ enemy
  CreateEnemy card -> do
    let
      enemy = createEnemy card
      enemyId = toId enemy
    pure $ g & entitiesL . enemiesL . at enemyId ?~ enemy
  -- CreateDiscardEnemy card -> do
  --   let
  --     enemy = createEnemy card
  --     enemyId = toId enemy
  --   pure $ g & encounterDiscardEntitiesL . enemiesL . at enemyId ?~ enemy
  CreateEnemyAtLocationMatching cardCode locationMatcher -> do
    matches' <- selectList locationMatcher
    when (null matches') (error "No matching locations")
    leadInvestigatorId <- getLeadInvestigatorId
    g <$ push
      (chooseOrRunOne
        leadInvestigatorId
        [ CreateEnemyAt cardCode lid Nothing | lid <- matches' ]
      )
  CreateEnemyAt card lid mtarget -> do
    let
      enemy = createEnemy card
      enemyId = toId enemy
    pushAll
      $ [ Will (EnemySpawn Nothing lid enemyId)
        , When (EnemySpawn Nothing lid enemyId)
        , EnemySpawn Nothing lid enemyId
        ]
      <> [ CreatedEnemyAt enemyId lid target | target <- maybeToList mtarget ]
    pure
      $ g
      & (entitiesL . enemiesL . at enemyId ?~ enemy)
  CreateEnemyEngagedWithPrey card -> do
    let
      enemy = createEnemy card
      enemyId = toId enemy
    pushAll
      [ Will (EnemySpawnEngagedWithPrey enemyId)
      , EnemySpawnEngagedWithPrey enemyId
      ]
    pure $ g & entitiesL . enemiesL . at enemyId ?~ enemy
  EnemySpawnEngagedWithPrey eid ->
    pure $ g & activeCardL .~ Nothing & enemiesInVoidL %~ deleteMap eid
  Discarded (InvestigatorTarget iid) card -> do
    push =<< checkWindows
      ((`Window` Window.Discarded iid card) <$> [Timing.When, Timing.After])
    pure g
  InvestigatorAssignDamage iid' (InvestigatorSource iid) _ n 0 | n > 0 -> do
    let
      historyItem = mempty { historyDealtDamageTo = [InvestigatorTarget iid'] }
      turn = isJust $ view turnPlayerInvestigatorIdL g
      setTurnHistory =
        if turn then turnHistoryL %~ insertHistory iid historyItem else id

    pure $ g & (phaseHistoryL %~ insertHistory iid historyItem) & setTurnHistory
  Msg.EnemyDamage eid iid _ _ n | n > 0 -> do
    let
      historyItem = mempty { historyDealtDamageTo = [EnemyTarget eid] }
      turn = isJust $ view turnPlayerInvestigatorIdL g
      setTurnHistory =
        if turn then turnHistoryL %~ insertHistory iid historyItem else id

    pure $ g & (phaseHistoryL %~ insertHistory iid historyItem) & setTurnHistory
  FoundEncounterCardFrom _ _ _ _ ->
    pure $ g & (focusedCardsL .~ mempty)
  FoundAndDrewEncounterCard _ _ _ ->
    pure $ g & (focusedCardsL .~ mempty)
  SearchCollectionForRandom iid source matcher -> do
    mcard <-
      case
        filter
          ((`cardMatch` matcher) . (`lookupPlayerCard` CardId nil))
          (toList allPlayerCards)
      of
        [] -> pure Nothing
        (x : xs) -> Just <$> (genPlayerCard =<< sample (x :| xs))
    g <$ push (RequestedPlayerCard iid source mcard)
  Surge iid _ -> g <$ push (InvestigatorDrawEncounterCard iid)
  InvestigatorEliminated iid -> pure $ g & playerOrderL %~ filter (/= iid)
  SetActiveInvestigator iid -> pure $ g & activeInvestigatorIdL .~ iid
  InvestigatorDrawEncounterCard iid -> do
    drawEncounterCardWindow <- checkWindows
      [Window Timing.When (Window.WouldDrawEncounterCard iid $ g ^. phaseL)]
    g <$ pushAll
      [ SetActiveInvestigator iid
      , drawEncounterCardWindow
      , InvestigatorDoDrawEncounterCard iid
      , SetActiveInvestigator (g ^. activeInvestigatorIdL)
      ]
  RevelationSkillTest iid (TreacherySource tid) skillType difficulty -> do
    card <- field TreacheryCard tid

    push $ BeginSkillTest
      iid
      (TreacherySource tid)
      (InvestigatorTarget iid)
      Nothing
      skillType
      difficulty
    pure $ g & (activeCardL ?~ card)
  Revelation iid (PlayerCardSource card) -> case toCardType card of
    AssetType -> do
      let
        asset = createAsset card
        assetId = toId asset
      -- Asset is assumed to have a revelation ability if drawn from encounter deck
      pushAll $ resolve $ Revelation iid (AssetSource assetId)
      pure $ g & (entitiesL . assetsL . at assetId ?~ asset)
    other ->
      error $ "Currently not handling Revelations from type " <> show other
  InvestigatorDrewEncounterCard iid card -> do
    let
      g' = g
        & focusedCardsL %~ filter ((/= Just card) . preview _EncounterCard)
        & foundCardsL %~ HashMap.map (filter ((/= Just card) . preview _EncounterCard))
    case toCardType card of
      EnemyType -> do
        let enemy = createEnemy card
        lid <- getJustLocation iid
        pushAll [InvestigatorDrawEnemy iid lid $ toId enemy, UnsetActiveCard]
        pure
          $ g'
          & (entitiesL . enemiesL . at (toId enemy) ?~ enemy)
          & (activeCardL ?~ EncounterCard card)
      TreacheryType -> g <$ push (DrewTreachery iid $ EncounterCard card)
      EncounterAssetType -> do
        let
          asset = createAsset card
          assetId = toId asset
        -- Asset is assumed to have a revelation ability if drawn from encounter deck
        pushAll $ resolve $ Revelation iid (AssetSource assetId)
        pure $ g' & (entitiesL . assetsL . at assetId ?~ asset)
      LocationType -> do
        let
          location = createLocation card
          locationId = toId location
        pushAll
          $ [ PlacedLocation (toName location) (toCardCode card) locationId
            , RevealLocation (Just iid) locationId
            ]
          <> resolve (Revelation iid (LocationSource locationId))
        pure $ g' & (entitiesL . locationsL . at locationId ?~ location)
      _ ->
        error
          $ "Unhandled card type: "
          <> show (toCardType card)
          <> ": "
          <> show card
  After (Revelation iid source) -> do
    keywords' <- case source of
      AssetSource _ -> pure mempty
      EnemySource eid -> field EnemyKeywords eid
      TreacherySource tid -> field TreacheryKeywords tid
      LocationSource lid -> field LocationKeywords lid
      _ -> error "oh, missed a source for after revelation"
    g <$ pushAll [ Surge iid source | Keyword.Surge `member` keywords' ]
  DrewTreachery iid (EncounterCard card) -> do
    let
      treachery = createTreachery card iid
      treacheryId = toId treachery
      historyItem = mempty { historyTreacheriesDrawn = [toCardCode treachery] }
      turn = isJust $ view turnPlayerInvestigatorIdL g
      setTurnHistory =
        if turn then turnHistoryL %~ insertHistory iid historyItem else id

    push (ResolveTreachery iid treacheryId)

    pure
      $ g
      & (entitiesL . treacheriesL . at treacheryId ?~ treachery)
      & (activeCardL ?~ EncounterCard card)
      & (phaseHistoryL %~ insertHistory iid historyItem)
      & setTurnHistory
  ResolveTreachery iid treacheryId -> do
    treachery <- getTreachery treacheryId
    checkWindowMessage <- checkWindows
      [ Window
          Timing.When
          (Window.DrawCard iid (toCard treachery) Deck.EncounterDeck)
      ]
    g <$ pushAll
      (checkWindowMessage
      : resolve (Revelation iid (TreacherySource treacheryId))
      <> [AfterRevelation iid treacheryId]
      )
  DrewTreachery iid (PlayerCard card) -> do
    let
      treachery = createTreachery card iid
      treacheryId = toId treachery
    -- player treacheries will not trigger draw treachery windows
    pushAll
      $ [ RemoveCardFromHand iid (toCardId card)
        | cdRevelation (toCardDef card)
        ]
      <> resolve (Revelation iid (TreacherySource treacheryId))
      <> [AfterRevelation iid treacheryId, UnsetActiveCard]

    let
      historyItem = mempty { historyTreacheriesDrawn = [toCardCode treachery] }
      turn = isJust $ view turnPlayerInvestigatorIdL g
      setTurnHistory =
        if turn then turnHistoryL %~ insertHistory iid historyItem else id

    pure
      $ g
      & (entitiesL . treacheriesL %~ insertMap treacheryId treachery)
      & (activeCardL ?~ PlayerCard card)
      & (phaseHistoryL %~ insertHistory iid historyItem)
      & setTurnHistory
  UnsetActiveCard -> pure $ g & activeCardL .~ Nothing
  AfterRevelation{} -> pure $ g & activeCardL .~ Nothing
  Discarded (AssetTarget aid) (EncounterCard _) ->
    pure $ g & entitiesL . assetsL %~ deleteMap aid
  Discarded (AssetTarget aid) _ -> pure $ g & entitiesL . assetsL %~ deleteMap aid
  DiscardedCost (AssetTarget aid) -> do
    -- When discarded as a cost, the entity may still need to be in the environment to handle ability resolution
    asset <- getAsset aid
    case assetController (toAttrs asset) of
      Nothing -> error "Unhandled: Asset was discarded for cost but was uncontrolled"
      Just iid -> do
        let dEntities = fromMaybe defaultEntities $ view (inDiscardEntitiesL . at iid) g
        pure $ g & inDiscardEntitiesL . at iid ?~ (dEntities & assetsL . at aid ?~ asset)
  DiscardedCost (SearchedCardTarget cid) -> do
    -- There is only one card, Astounding Revelation, that does this so we just hard code for now
    iid <- getActiveInvestigatorId
    let
      event' = lookupEvent "06023" iid (EventId cid)
      dEntities = fromMaybe defaultEntities $ view (inDiscardEntitiesL . at iid) g
    pure $ g & inDiscardEntitiesL . at iid ?~ (dEntities & eventsL . at (toId event') ?~ event')
  ClearDiscardCosts -> pure $ g & inDiscardEntitiesL .~ mempty
  Discarded (TreacheryTarget aid) _ -> pure $ g & entitiesL . treacheriesL %~ deleteMap aid
  Exiled (AssetTarget aid) _ -> pure $ g & entitiesL . assetsL %~ deleteMap aid
  Discard (EventTarget eid) -> do
    -- an event might need to be converted back to its original card
    event' <- getEvent eid
    modifiers' <- getModifiers GameSource (EventTarget eid)
    if RemoveFromGameInsteadOfDiscard `elem` modifiers'
      then g <$ push (RemoveFromGame (EventTarget eid))
      else do
        card <- field EventCard eid
        case card of
          PlayerCard pc ->
            if PlaceOnBottomOfDeckInsteadOfDiscard `elem` modifiers'
              then push $ PlaceOnBottomOfDeck (eventOwner $ toAttrs event') pc
              else push $ AddToDiscard (eventOwner $ toAttrs event') pc
          EncounterCard _ -> error "Unhandled"
        pure $ g & entitiesL . eventsL %~ deleteMap eid
  Discard (TreacheryTarget tid) -> do
    treachery <- getTreachery tid
    let card = lookupCard (toCardCode treachery) (unTreacheryId tid)
    case card of
      PlayerCard pc -> do
        let
          ownerId = fromJustNote "owner was not set" $ treacheryOwner $ toAttrs treachery
        push (AddToDiscard ownerId pc { pcBearer = Just ownerId })
      EncounterCard _ -> pure ()
    pure $ g & entitiesL . treacheriesL %~ deleteMap tid
  _ -> pure g

-- Entity id generation should be random, so even though this is pure now
-- this is using a Monad
addEntity :: Monad m => Investigator -> Entities -> Card -> m Entities
addEntity i e card = case card of
  PlayerCard pc -> case toCardType pc of
    EventType -> do
      let event' = createEvent card (toId i)
      pure $ e & eventsL %~ insertEntity event'
    AssetType -> do
      let asset = createAsset card
      pure $ e & assetsL %~ insertMap (toId asset) asset
    _ -> error "Unhandled"
  EncounterCard ec -> case toCardType ec of
    TreacheryType -> do
      let treachery = createTreachery card (toId i)
      pure $ e & treacheriesL %~ insertMap (toId treachery) treachery
    _ -> error "Unhandled"

-- TODO: Clean this up, the found of stuff is a bit messy
preloadEntities :: Game -> GameT Game
preloadEntities g = do
  let
    investigators = view (entitiesL . investigatorsL) g
    preloadHandEntities entities investigator' = do
      let handEffectCards = filter (cdCardInHandEffects . toCardDef) . investigatorHand $ toAttrs investigator'
      if null handEffectCards
         then pure entities
         else do
           handEntities <- foldM (addEntity investigator') defaultEntities handEffectCards
           pure $ insertMap (toId investigator') handEntities entities
  let
    foundOfElems :: Investigator -> [Card]
    foundOfElems = concat . HashMap.elems . investigatorFoundCards . toAttrs

    searchEffectCards :: [Card] = filter (cdCardInSearchEffects . toCardDef) $
      ((concat . HashMap.elems $ gameFoundCards g) :: [Card])
      <> (concatMap foundOfElems (view (entitiesL . investigatorsL) g) :: [Card])
  active <- getInvestigator =<< getActiveInvestigatorId
  searchEntities <- foldM (addEntity active) defaultEntities searchEffectCards
  handEntities <- foldM preloadHandEntities mempty investigators
  pure $ g { gameInHandEntities = handEntities, gameInSearchEntities = searchEntities }

instance RunMessage Game where
  runMessage msg g = do
    preloadEntities g
      >>= runPreGameMessage msg
      >>= traverseOf (modeL . here) (runMessage msg)
      >>= traverseOf (modeL . there) (runMessage msg)
      >>= traverseOf entitiesL (runMessage msg)
      >>= itraverseOf (inHandEntitiesL . itraversed) (\i e -> runMessage (InHand i msg) e)
      >>= itraverseOf (inDiscardEntitiesL . itraversed) (\i e -> runMessage (InDiscard i msg) e)
      >>= traverseOf inSearchEntitiesL (runMessage (InSearch msg))
      >>= traverseOf (skillTestL . traverse) (runMessage msg)
      >>= runGameMessage msg
      >>= (pure . set enemyMovingL Nothing)
