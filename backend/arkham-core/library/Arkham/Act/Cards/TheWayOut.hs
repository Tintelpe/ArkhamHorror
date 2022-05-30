module Arkham.Act.Cards.TheWayOut
  ( TheWayOut(..)
  , theWayOut
  ) where

import Arkham.Prelude

import Arkham.Act.Attrs
import Arkham.Act.Cards qualified as Cards
import Arkham.Location.Cards qualified as Locations
import Arkham.Act.Runner
import Arkham.Classes
import Arkham.Matcher
import Arkham.Ability
import Arkham.Criteria

newtype TheWayOut = TheWayOut ActAttrs
  deriving anyclass (IsAct, HasModifiersFor env)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

theWayOut :: ActCard TheWayOut
theWayOut = act (3, A) TheWayOut Cards.theWayOut Nothing

instance HasAbilities TheWayOut where
  getAbilities (TheWayOut a) =
    [ restrictedAbility
          a
          2
          (EachUndefeatedInvestigator $ InvestigatorAt $ locationIs
            Locations.theGateToHell
          )
        $ Objective
        $ ForcedAbility AnyWindow
    ]

instance ActRunner env => RunMessage env TheWayOut where
  runMessage msg (TheWayOut attrs) = TheWayOut <$> runMessage msg attrs
