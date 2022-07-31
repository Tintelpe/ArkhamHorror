module Arkham.Trait (
  Trait (..),
  EnemyTrait (..),
  HasTraits (..),
) where

import Arkham.Prelude

newtype EnemyTrait = EnemyTrait {unEnemyTrait :: Trait}

data Trait
  = Abomination
  | Agency
  | Ally
  | Altered
  | Ancient
  | AncientOne
  | Arkham
  | ArkhamAsylum
  | Armor
  | Artist
  | Assistant
  | Augury
  | Avatar
  | Bayou
  | Believer
  | Blessed
  | Blunder
  | Boat
  | Bold
  | Boon
  | Bridge
  | Byakhee
  | Bystander
  | Campsite
  | Carnevale
  | Cave
  | Central
  | Charm
  | Chosen
  | Civic
  | Clairvoyant
  | Clothing
  | CloverClub
  | Composure
  | Condition
  | Connection
  | Conspirator
  | Courage
  | Creature
  | Criminal
  | Cultist
  | Curse
  | Cursed
  | DarkYoung
  | DeepOne
  | Desperate
  | Detective
  | Developed
  | Dhole
  | Dreamer
  | Dreamlands
  | Drifter
  | Dunwich
  | Eldritch
  | Elite
  | Endtimes
  | Evidence
  | Exhibit
  | Expert
  | Extradimensional
  | Eztli
  | Fated
  | Favor
  | Firearm
  | Flaw
  | Footwear
  | Fortune
  | Gambit
  | Geist
  | Ghoul
  | Grant
  | GroundFloor
  | Gug
  | Hazard
  | Hex
  | HistoricalSociety
  | Human
  | Humanoid
  | Hunter
  | Illicit
  | Improvised
  | Injury
  | Innate
  | Insight
  | Instrument
  | Item
  | Job
  | Jungle
  | Key
  | Lodge
  | Lunatic
  | Madness
  | Mask
  | Medic
  | Melee
  | Miskatonic
  | Monster
  | Mystery
  | NewOrleans
  | Nightgaunt
  | Obstacle
  | Occult
  | Omen
  | Otherworld
  | Pact
  | Paradox
  | Paris
  | Passageway
  | Patron
  | Performer
  | Poison
  | Police
  | Power
  | Practiced
  | Private
  | Rail
  | Ranged
  | Relic
  | Reporter
  | Research
  | Ritual
  | Riverside
  | Ruins
  | Scheme
  | Scholar
  | Science
  | SecondFloor
  | SentinelHill
  | Serpent
  | Service
  | Servitor
  | Shoggoth
  | SilverTwilight
  | Socialite
  | Song
  | Sorcerer
  | Spell
  | Spirit
  | Summon
  | Supply
  | Syndicate
  | Tactic
  | Talent
  | Tarot
  | Task
  | Tentacle
  | Terror
  | ThirdFloor
  | Tindalos
  | Tome
  | Tool
  | Train
  | Trap
  | Trick
  | Unhallowed
  | Upgrade
  | Venice
  | Veteran
  | Warden
  | Wayfarer
  | Weapon
  | Wilderness
  | Witch
  | Woods
  | Yithian
  deriving stock (Show, Eq, Generic, Read)
  deriving anyclass (ToJSON, FromJSON, Hashable)

class HasTraits a where
  toTraits :: a -> HashSet Trait
