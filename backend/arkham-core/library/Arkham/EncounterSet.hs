{-# LANGUAGE TemplateHaskell #-}
module Arkham.EncounterSet where

import Arkham.Prelude

import Data.Aeson.TH

data EncounterSet
  = TheGathering
  | TheMidnightMasks
  | TheDevourerBelow
  | CultOfUmordhoth
  | Rats
  | Ghouls
  | StrikingFear
  | AncientEvils
  | ChillingCold
  | Nightgaunts
  | DarkCult
  | LockedDoors
  | AgentsOfHastur
  | AgentsOfYogSothoth
  | AgentsOfShubNiggurath
  | AgentsOfCthulhu
  | ExtracurricularActivity
  | TheHouseAlwaysWins
  | ArmitagesFate
  | TheMiskatonicMuseum
  | TheEssexCountyExpress
  | BloodOnTheAltar
  | UndimensionedAndUnseen
  | WhereDoomAwaits
  | LostInTimeAndSpace
  | Sorcery
  | BishopsThralls
  | Dunwich
  | Whippoorwills
  | BadLuck
  | BeastThralls
  | NaomisCrew
  | TheBeyond
  | HideousAbominations
  | CurtainCall
  | TheLastKing
  | Delusions
  | Byakhee
  | InhabitantsOfCarcosa
  | EvilPortents
  | Hauntings
  | HastursGift
  | CultOfTheYellowSign
  | DecayAndFilth
  | TheStranger
  | EchoesOfThePast
  | TheUnspeakableOath
  | APhantomOfTruth
  | ThePallidMask
  | BlackStarsRise
  | DimCarcosa
  | TheUntamedWilds
  | TheDoomOfEztli
  | Rainforest
  | Serpents
  | Expedition
  | AgentsOfYig
  | GuardiansOfTime
  | DeadlyTraps
  | TemporalFlux
  | ForgottenRuins
  | PnakoticBrotherhood
  | YigsVenom
  | Poison
  | ThreadsOfFate
  | TheBoundaryBeyond
  | HeartOfTheElders
  | PillarsOfJudgement
  | KnYan
  | TheCityOfArchives
  | TheDepthsOfYoth
  | ShatteredAeons
  | TurnBackTime
  | DisappearanceAtTheTwilightEstate
  | TheWitchingHour
  | AtDeathsDoorstep
  | TheWatcher
  | AgentsOfAzathoth
  | AnettesCoven
  | Witchcraft
  | SilverTwilightLodge
  | CityOfSins
  | SpectralPredators
  | TrappedSpirits
  | RealmOfDeath
  | InexorableFate
  | TheSecretName
  | TheWagesOfSin
  | ForTheGreaterGood
  | UnionAndDisillusion
  | InTheClutchesOfChaos
  | BeforeTheBlackThrone
  | ReturnToTheGathering
  | ReturnToTheMidnightMasks
  | ReturnToTheDevourerBelow
  | GhoulsOfUmordhoth
  | TheDevourersCult
  | ReturnCultOfUmordhoth
  | TheBayou
  | CurseOfTheRougarou
  | CarnevaleOfHorrors
  | Test
  deriving stock (Show, Eq, Ord, Bounded, Enum)

$(deriveJSON defaultOptions ''EncounterSet)
