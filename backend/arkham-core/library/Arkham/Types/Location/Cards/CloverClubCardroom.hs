{-# LANGUAGE UndecidableInstances #-}

module Arkham.Types.Location.Cards.CloverClubCardroom
  ( cloverClubCardroom
  , CloverClubCardroom(..)
  )
where

import Arkham.Import

import qualified Arkham.Types.EncounterSet as EncounterSet
import Arkham.Types.Game.Helpers
import Arkham.Types.Location.Attrs
import Arkham.Types.Location.Runner
import Arkham.Types.RequestedTokenStrategy
import Arkham.Types.Trait hiding (Cultist)

newtype CloverClubCardroom = CloverClubCardroom Attrs
  deriving newtype (Show, ToJSON, FromJSON)

cloverClubCardroom :: CloverClubCardroom
cloverClubCardroom = CloverClubCardroom $ baseAttrs
  "02073"
  (LocationName "Clover Club Cardroom" Nothing)
  EncounterSet.TheHouseAlwaysWins
  3
  (Static 0)
  Triangle
  [Circle, Square, Diamond]
  [CloverClub]

instance HasModifiersFor env CloverClubCardroom where
  getModifiersFor = noModifiersFor

ability :: Attrs -> Ability
ability attrs = (mkAbility
                  (toSource attrs)
                  1
                  (ActionAbility Nothing $ Costs [ActionCost 1, ResourceCost 2]
                  )
                )
  { abilityLimit = PerGame
  }

instance ActionRunner env => HasActions env CloverClubCardroom where
  getActions iid NonFast (CloverClubCardroom attrs@Attrs {..})
    | locationRevealed = withBaseActions iid NonFast attrs $ do
      step <- unActStep . getStep <$> ask
      unused <- getIsUnused iid (ability attrs)
      pure
        [ ActivateCardAbilityAction iid (ability attrs)
        | iid `member` locationInvestigators && step == 1 && unused
        ]
  getActions iid window (CloverClubCardroom attrs) =
    getActions iid window attrs

instance LocationRunner env => RunMessage env CloverClubCardroom where
  runMessage msg l@(CloverClubCardroom attrs@Attrs {..}) = case msg of
    UseCardAbility iid source _ 1 | isSource attrs source && locationRevealed ->
      l <$ unshiftMessage (RequestTokens source (Just iid) 1 SetAside)
    RequestedTokens source (Just iid) tokens | isSource attrs source -> do
      let
        msgs = concatMap
          (\case
            ElderSign -> [GainClues iid 2, TakeResources iid 2 False]
            PlusOne -> []
            Zero -> [GainClues iid 2]
            MinusOne -> []
            MinusTwo -> [GainClues iid 2]
            MinusThree -> []
            MinusFour -> [GainClues iid 2]
            MinusFive -> []
            MinusSix -> [GainClues iid 2]
            MinusSeven -> []
            MinusEight -> [GainClues iid 2]
            Skull -> []
            Cultist -> []
            Tablet -> []
            ElderThing -> []
            AutoFail -> []
          )
          tokens
      l <$ unshiftMessages (msgs <> [ResetTokens source])
    _ -> CloverClubCardroom <$> runMessage msg attrs
