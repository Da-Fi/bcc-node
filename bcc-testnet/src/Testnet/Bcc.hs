{-# LANGUAGE CPP #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeApplications #-}

{-# OPTIONS_GHC -Wno-unused-imports -Wno-unused-local-binds -Wno-unused-matches #-}

#if !defined(mingw32_HOST_OS)
#define UNIX
#endif

module Testnet.Bcc
  ( ForkPoint(..)
  , TestnetOptions(..)
  , defaultTestnetOptions

  , Era(..)
  , TestnetRuntime (..)
  , Wallet(..)

  , testnet
  ) where

#ifdef UNIX
import           Prelude (map)
#endif

import           Control.Applicative (pure)
import           Control.Monad
import           Data.Aeson ((.=), Value)
import           Data.Bool
import           Data.Eq
import           Data.Function
import           Data.Functor
import           Data.Int
import           Data.List ((\\))
import           Data.Maybe
import           Control.Monad.IO.Class (liftIO)
import           Data.Either
import           Data.Ord
import           Data.Semigroup
import           Data.String
import           GHC.Enum
import           GHC.Float
import           GHC.Num
import           GHC.Real
import           Hedgehog.Extras.Stock.IO.Network.Sprocket (Sprocket (..))
import           Hedgehog.Extras.Stock.Time
import           System.FilePath.Posix ((</>))
import           System.IO (FilePath)
import           Text.Read
import           Text.Show

#ifdef UNIX
import           System.Posix.Files
#endif

import qualified Data.Aeson as J
import qualified Data.Yaml as Y
import qualified Data.HashMap.Lazy as HM
import qualified Data.List as L
import qualified Data.Map as M
import qualified Data.Time.Clock as DTC
import qualified Hedgehog as H
import qualified Hedgehog.Extras.Stock.Aeson as J
import qualified Hedgehog.Extras.Stock.IO.File as IO
import qualified Hedgehog.Extras.Stock.IO.Network.Socket as IO
import qualified Hedgehog.Extras.Stock.IO.Network.Sprocket as IO
import qualified Hedgehog.Extras.Stock.String as S
import qualified Hedgehog.Extras.Stock.OS as OS
import qualified Hedgehog.Extras.Test.Base as H
import qualified Hedgehog.Extras.Test.Concurrent as H
import qualified Hedgehog.Extras.Test.File as H
import qualified Hedgehog.Extras.Test.Network as H
import qualified Hedgehog.Extras.Test.Process as H
import qualified System.Directory as IO
import qualified System.Environment as IO
import qualified System.IO as IO
import qualified System.Info as OS
import qualified System.Process as IO
import qualified Test.Process as H
import qualified Testnet.Conf as H

{- HLINT ignore "Reduce duplication" -}
{- HLINT ignore "Redundant <&>" -}
{- HLINT ignore "Redundant flip" -}
{- HLINT ignore "Redundant id" -}
{- HLINT ignore "Use let" -}

data ForkPoint
  = AtVersion Int
  | AtEpoch Int
  deriving (Show, Eq, Read)

data Era = Cole | Sophie | Evie | Jen | Aurum deriving (Eq, Enum, Bounded, Read, Show)

data TestnetOptions = TestnetOptions
  { numBftNodes :: Int
  , numPoolNodes :: Int
  , era :: Era
  , epochLength :: Int
  , slotLength :: Double
  , activeSlotsCoeff :: Double
  } deriving (Eq, Show)

defaultTestnetOptions :: TestnetOptions
defaultTestnetOptions = TestnetOptions
  { numBftNodes = 2
  , numPoolNodes = 1
  , era = Aurum
  , epochLength = 1500
  , slotLength = 0.2
  , activeSlotsCoeff = 0.2
  }

data TestnetRuntime = TestnetRuntime
  { configurationFile :: FilePath
  , testnetMagic :: Int
  , allNodes :: [String]
  , bftSprockets :: [Sprocket]
  , wallets :: [Wallet]
  } deriving (Eq, Show)

data Wallet = Wallet
  { paymentVKey :: FilePath
  , paymentSKey :: FilePath
  } deriving (Eq, Show)

ifaceAddress :: String
ifaceAddress = "127.0.0.1"

-- | For an unknown reason, CLI commands are a lot slowere on Windows than on Linux and
-- MacOS.  We need to allow a lot more time to set up a testnet.
startTimeOffsetSeconds :: DTC.NominalDiffTime
startTimeOffsetSeconds = if OS.isWin32 then 90 else 15

testnet :: TestnetOptions -> H.Conf -> H.Integration TestnetRuntime
testnet testnetOptions H.Conf {..} = do
  void $ H.note OS.os
  currentTime <- H.noteShowIO DTC.getCurrentTime
  startTime <- H.noteShow $ DTC.addUTCTime startTimeOffsetSeconds currentTime
  configurationTemplate <- H.noteShow $ base </> "configuration/defaults/cole-mainnet/configuration.yaml"
  configurationFile <- H.noteShow $ tempAbsPath </> "configuration.yaml"

  let bftNodesN = [1 .. numBftNodes testnetOptions]
  let poolNodesN = [1 .. numPoolNodes testnetOptions]
  let bftNodes = ("node-bft" <>) . show @Int <$> bftNodesN
  let poolNodes = ("node-pool" <>) . show @Int <$> poolNodesN
  let allNodes = bftNodes <> poolNodes
  let initSupply = 1000000000
  let maxSupply = 1000000000
  let fundsPerGenesisAddress = initSupply `div` numBftNodes testnetOptions
  let fundsPerColeAddress = fundsPerGenesisAddress * 9 `div` 10
  let userPoolN = poolNodesN

  allPorts <- H.noteShowIO $ IO.allocateRandomPorts (L.length allNodes)
  nodeToPort <- H.noteShow (M.fromList (L.zip allNodes allPorts))

  let securityParam = 10

  H.createDirectoryIfMissing logDir

  H.readFile configurationTemplate >>= H.writeFile configurationFile

  forkOptions <- pure $ id
    . HM.insert "EnableLogMetrics" (J.toJSON False)
    . HM.insert "EnableLogging" (J.toJSON True)
    . case era testnetOptions of
        Cole -> id
          . HM.insert "LastKnownBlockVersion-Major" (J.toJSON @Int 1)

        Sophie -> id
          . HM.insert "TestSophieHardForkAtEpoch" (J.toJSON @Int 0)
          . HM.insert "LastKnownBlockVersion-Major" (J.toJSON @Int 2)

        Evie -> id
          . HM.insert "TestSophieHardForkAtEpoch" (J.toJSON @Int 0)
          . HM.insert "TestEvieHardForkAtEpoch" (J.toJSON @Int 0)
          . HM.insert "LastKnownBlockVersion-Major" (J.toJSON @Int 3)

        Jen -> id
          . HM.insert "TestSophieHardForkAtEpoch" (J.toJSON @Int 0)
          . HM.insert "TestEvieHardForkAtEpoch" (J.toJSON @Int 0)
          . HM.insert "TestJenHardForkAtEpoch" (J.toJSON @Int 0)
          . HM.insert "LastKnownBlockVersion-Major" (J.toJSON @Int 4)

        Aurum -> id
          . HM.insert "TestSophieHardForkAtEpoch" (J.toJSON @Int 0)
          . HM.insert "TestEvieHardForkAtEpoch" (J.toJSON @Int 0)
          . HM.insert "TestJenHardForkAtEpoch" (J.toJSON @Int 0)
          . HM.insert "TestAurumHardForkAtEpoch" (J.toJSON @Int 0)
          . HM.insert "LastKnownBlockVersion-Major" (J.toJSON @Int 5)

  -- We're going to use really quick epochs (300 seconds), by using short slots 0.2s
  -- and K=10, but we'll keep long KES periods so we don't have to bother
  -- cycling KES keys
  H.rewriteYamlFile (tempAbsPath </> "configuration.yaml") . J.rewriteObject
    $ HM.insert "Protocol" (J.toJSON @String "Bcc")
    . HM.insert "PBftSignatureThreshold" (J.toJSON @Double 0.6)
    . HM.insert "minSeverity" (J.toJSON @String "Debug")
    . HM.insert "ColeGenesisFile" (J.toJSON @String "cole/genesis.json")
    . HM.insert "SophieGenesisFile" (J.toJSON @String "sophie/genesis.json")
    . HM.insert "AurumGenesisFile" (J.toJSON @String "sophie/genesis.aurum.json")
    . HM.insert "RequiresNetworkMagic" (J.toJSON @String "RequiresMagic")
    . HM.insert "LastKnownBlockVersion-Major" (J.toJSON @Int 1)
    . HM.insert "LastKnownBlockVersion-Minor" (J.toJSON @Int 0)
    . HM.insert "TraceBlockchainTime" (J.toJSON True)
    . HM.delete "GenesisFile"
    . HM.insert "TestEnableDevelopmentHardForkEras" (J.toJSON @Bool True)
    . HM.insert "TestEnableDevelopmentNetworkProtocols" (J.toJSON @Bool True)
    . forkOptions

  forM_ allNodes $ \node -> do
    H.createDirectoryIfMissing $ tempAbsPath </> node
    H.createDirectoryIfMissing $ tempAbsPath </> node </> "cole"
    H.createDirectoryIfMissing $ tempAbsPath </> node </> "sophie"

  -- Make topology files
  forM_ allNodes $ \node -> do
    let port = fromJust $ M.lookup node nodeToPort
    H.lbsWriteFile (tempAbsPath </> node </> "topology.json") $ J.encode $
      J.object
      [ "Producers" .= J.toJSON
        [ J.object
          [ "addr" .= J.toJSON @String ifaceAddress
          , "port" .= J.toJSON @Int peerPort
          , "valency" .= J.toJSON @Int 1
          ]
        | peerPort <- allPorts \\ [port]
        ]
      ]
    H.writeFile (tempAbsPath </> node </> "port") (show port)

  H.lbsWriteFile (tempAbsPath </> "cole.genesis.spec.json") . J.encode $ J.object
    [ "heavyDelThd" .= J.toJSON @String "300000000000"
    , "maxBlockSize" .= J.toJSON @String "2000000"
    , "maxTxSize" .= J.toJSON @String "4096"
    , "maxHeaderSize" .= J.toJSON @String "2000000"
    , "maxProposalSize" .= J.toJSON @String "700"
    , "mpcThd" .= J.toJSON @String "20000000000000"
    , "scriptVersion" .= J.toJSON @Int 0
    , "slotDuration" .= J.toJSON @String "1000"
    , "softforkRule" .= J.object
      [ "initThd" .= J.toJSON @String "900000000000000"
      , "minThd" .= J.toJSON @String "600000000000000"
      , "thdDecrement" .= J.toJSON @String "50000000000000"
      ]
    , "txFeePolicy" .= J.object
      [ "multiplier" .= J.toJSON @String "43946000000"
      , "summand" .= J.toJSON @String "155381000000000"
      ]
    , "unlockStakeEpoch" .= J.toJSON @String "18446744073709551615"
    , "updateImplicit" .= J.toJSON @String "10000"
    , "updateProposalThd" .= J.toJSON @String "100000000000000"
    , "updateVoteThd" .= J.toJSON @String "1000000000000"
    ]

  -- stuff
  void . H.execCli $
    [ "cole"
    , "genesis"
    , "genesis"
    , "--protocol-magic", show @Int testnetMagic
    , "--start-time", showUTCTimeSeconds startTime
    , "--k", show @Int securityParam
    , "--n-poor-addresses", "0"
    , "--n-delegate-addresses", show @Int (numBftNodes testnetOptions)
    , "--total-balance", show @Int initSupply
    , "--delegate-share", "1"
    , "--avvm-entry-count", "0"
    , "--avvm-entry-balance", "0"
    , "--protocol-parameters-file", tempAbsPath </> "cole.genesis.spec.json"
    , "--genesis-output-dir", tempAbsPath </> "cole"
    ]

  H.renameFile
    (tempAbsPath </> "cole.genesis.spec.json")
    (tempAbsPath </> "cole/genesis.spec.json")

  -- Symlink the BFT operator keys from the genesis delegates, for uniformity
  forM_ bftNodesN $ \n -> do
    H.createFileLink (tempAbsPath </> "cole/delegate-keys.00" <> show @Int (n - 1) <> ".key") (tempAbsPath </> "node-bft" <> show @Int n </> "cole/delegate.key")
    H.createFileLink (tempAbsPath </> "cole/delegation-cert.00" <> show @Int (n - 1) <> ".json") (tempAbsPath </> "node-bft" <> show @Int n </> "cole/delegate.cert")

  -- Create keys and addresses to withdraw the initial UTxO into
  forM_ bftNodesN $ \n -> do
    void $ H.execCli
      [ "keygen"
      , "--secret", tempAbsPath </> "cole/payment-keys.00" <> show @Int (n - 1) <> ".key"
      ]

    H.execCli
      [ "signing-key-address"
      , "--testnet-magic", show @Int testnetMagic
      , "--secret", tempAbsPath </> "cole/payment-keys.00" <> show @Int (n - 1) <> ".key"
      ] >>= H.writeFile (tempAbsPath </> "cole/address-00" <> show @Int (n - 1))

    -- Write Genesis addresses to files
    H.execCli
      [ "signing-key-address"
      , "--testnet-magic", show @Int testnetMagic
      , "--secret", tempAbsPath </> "cole/genesis-keys.00" <> show @Int (n - 1) <> ".key"
      ] >>= H.writeFile (tempAbsPath </> "cole/genesis-address-00" <> show @Int (n - 1))

  do
    richAddrFrom <- S.firstLine <$> H.readFile (tempAbsPath </> "cole/genesis-address-000")
    txAddr <- S.firstLine <$> H.readFile (tempAbsPath </> "cole/address-000")

    -- Create Cole address that moves funds out of the genesis UTxO into a regular
    -- address.
    void $ H.execCli
      [ "issue-genesis-utxo-expenditure"
      , "--genesis-json", tempAbsPath </> "cole/genesis.json"
      , "--testnet-magic", show @Int testnetMagic
      , "--tx", tempAbsPath </> "tx0.tx"
      , "--wallet-key", tempAbsPath </> "cole/delegate-keys.000.key"
      , "--rich-addr-from", richAddrFrom
      , "--txout", show @(String, Int) (txAddr, fundsPerGenesisAddress)
      ]

  -- Update Proposal and votes
  void $ H.execCli
    [ "cole", "governance", "create-update-proposal"
    , "--filepath", tempAbsPath </> "update-proposal"
    , "--testnet-magic", show @Int testnetMagic
    , "--signing-key", tempAbsPath </> "cole/delegate-keys.000.key"
    , "--protocol-version-major", "1"
    , "--protocol-version-minor", "0"
    , "--protocol-version-alt", "0"
    , "--application-name", "bcc-sl"
    , "--software-version-num", "1"
    , "--system-tag", "linux"
    , "--installer-hash", "0"
    ]

  forM_ bftNodesN $ \n -> do
    void $ H.execCli
      [ "cole", "governance", "create-proposal-vote"
      , "--proposal-filepath", tempAbsPath </> "update-proposal"
      , "--testnet-magic", show @Int testnetMagic
      , "--signing-key", tempAbsPath </> "cole/delegate-keys.00" <> show @Int (n - 1) <> ".key"
      , "--vote-yes"
      , "--output-filepath", tempAbsPath </> "update-vote.00" <> show @Int (n - 1)
      ]

  void $ H.execCli
    [ "cole", "governance", "create-update-proposal"
    , "--filepath", tempAbsPath </> "update-proposal-1"
    , "--testnet-magic", show @Int testnetMagic
    , "--signing-key", tempAbsPath </> "cole/delegate-keys.000.key"
    , "--protocol-version-major", "2"
    , "--protocol-version-minor", "0"
    , "--protocol-version-alt", "0"
    , "--application-name", "bcc-sl"
    , "--software-version-num", "1"
    , "--system-tag", "linux"
    , "--installer-hash", "0"
    ]

  forM_ bftNodesN $ \n ->
    void $ H.execCli
      [ "cole", "governance", "create-proposal-vote"
      , "--proposal-filepath", tempAbsPath </> "update-proposal-1"
      , "--testnet-magic", show @Int testnetMagic
      , "--signing-key", tempAbsPath </> "cole/delegate-keys.00" <> show @Int (n - 1) <> ".key"
      , "--vote-yes"
      , "--output-filepath", tempAbsPath </> "update-vote-1.00" <> show @Int (n - 1)
      ]

  -- Generated genesis keys and genesis files
  H.noteEachM_ . H.listDirectory $ tempAbsPath </> "cole"

  -- Set up our template
  H.createDirectoryIfMissing $ tempAbsPath </> "sophie"

  void $ H.execCli
    [ "genesis", "create"
    , "--testnet-magic", show @Int testnetMagic
    , "--genesis-dir", tempAbsPath </> "sophie"
    , "--start-time", formatIso8601 startTime
    ]

  -- Then edit the genesis.spec.json ...

  -- We're going to use really quick epochs (300 seconds), by using short slots 0.2s
  -- and K=10, but we'll keep long KES periods so we don't have to bother
  -- cycling KES keys
  H.rewriteJsonFile (tempAbsPath </> "sophie/genesis.spec.json") . J.rewriteObject
    $ HM.insert "slotLength" (J.toJSON @Double 0.2)
    . HM.insert "activeSlotsCoeff" (J.toJSON @Double (activeSlotsCoeff testnetOptions))
    . HM.insert "securityParam" (J.toJSON @Int 10)
    . HM.insert "epochLength" (J.toJSON @Int (epochLength testnetOptions))
    . HM.insert "slotLength" (J.toJSON @Double 0.2)
    . HM.insert "maxEntropicSupply" (J.toJSON @Int maxSupply)
    . flip HM.adjust "protocolParams"
      ( J.rewriteObject (HM.insert "decentralisationParam" (J.toJSON @Double 0.7))
      )

  -- Now generate for real:
  void $ H.execCli
    [ "genesis", "create"
    , "--testnet-magic", show @Int testnetMagic
    , "--genesis-dir", tempAbsPath </> "sophie"
    , "--gen-genesis-keys", show @Int (numBftNodes testnetOptions)
    , "--start-time", formatIso8601 startTime
    , "--gen-utxo-keys", show @Int (numPoolNodes testnetOptions)
    ]
#ifdef UNIX
  --TODO: Remove me after #1948 is merged.
  let vrfPath n = tempAbsPath </> "sophie" </> "delegate-keys" </> "delegate" <> n <> ".vrf.skey"
  H.evalIO . forM_ bftNodesN $ \n -> setFileMode (vrfPath (show @Int n)) ownerModes
#endif
  -- Generated genesis keys and genesis files
  H.noteEachM_ . H.listDirectory $ tempAbsPath </> "sophie"

  H.rewriteJsonFile (tempAbsPath </> "sophie/genesis.json") . J.rewriteObject
    $ flip HM.adjust "protocolParams"
      ( J.rewriteObject
        ( flip HM.adjust "protocolVersion" 
          ( J.rewriteObject (HM.insert "major" (J.toJSON @Int 2))
          )
        )
      )
    . HM.insert "updateQuorum" (J.toJSON @Int 2)

  -- Generated sophie/genesis.json
  H.cat $ tempAbsPath </> "sophie/genesis.json"

  -- Generated aurum/genesis.json
  --TODO: rationalise the naming convention on these genesis json files.
  H.cat $ tempAbsPath </> "sophie/genesis.aurum.json"

  -- Make the pool operator cold keys
  -- This was done already for the BFT nodes as part of the genesis creation
  forM_ poolNodes $ \node -> do
    void $ H.execCli
      [ "node", "key-gen"
      , "--cold-verification-key-file", tempAbsPath </> node </> "sophie/operator.vkey"
      , "--cold-signing-key-file", tempAbsPath </> node </> "sophie/operator.skey"
      , "--operational-certificate-issue-counter-file", tempAbsPath </> node </> "sophie/operator.counter"
      ]

    void $ H.execCli
      [ "node", "key-gen-VRF"
      , "--verification-key-file", tempAbsPath </> node </> "sophie/vrf.vkey"
      , "--signing-key-file", tempAbsPath </> node </> "sophie/vrf.skey"
      ]
#ifdef UNIX
    --TODO: Remove me after #1948 is merged.
    H.evalIO $ setFileMode (tempAbsPath </> node </> "sophie/vrf.skey") ownerModes
#endif
  -- Symlink the BFT operator keys from the genesis delegates, for uniformity
  forM_ bftNodesN $ \n -> do
    H.createFileLink (tempAbsPath </> "sophie/delegate-keys/delegate" <> show @Int n <> ".skey") (tempAbsPath </> "node-bft" <> show @Int n </> "sophie/operator.skey")
    H.createFileLink (tempAbsPath </> "sophie/delegate-keys/delegate" <> show @Int n <> ".vkey") (tempAbsPath </> "node-bft" <> show @Int n </> "sophie/operator.vkey")
    H.createFileLink (tempAbsPath </> "sophie/delegate-keys/delegate" <> show @Int n <> ".counter") (tempAbsPath </> "node-bft" <> show @Int n </> "sophie/operator.counter")
    H.createFileLink (tempAbsPath </> "sophie/delegate-keys/delegate" <> show @Int n <> ".vrf.vkey") (tempAbsPath </> "node-bft" <> show @Int n </> "sophie/vrf.vkey")
    H.createFileLink (tempAbsPath </> "sophie/delegate-keys/delegate" <> show @Int n <> ".vrf.skey") (tempAbsPath </> "node-bft" <> show @Int n </> "sophie/vrf.skey")

  -- Make hot keys and for all nodes
  forM_ allNodes $ \node -> do
    void $ H.execCli
      [ "node", "key-gen-KES"
      , "--verification-key-file", tempAbsPath </> node </> "sophie/kes.vkey"
      , "--signing-key-file",      tempAbsPath </> node </> "sophie/kes.skey"
      ]

    void $ H.execCli
      [ "node", "issue-op-cert"
      , "--kes-period", "0"
      , "--kes-verification-key-file", tempAbsPath </> node </> "sophie/kes.vkey"
      , "--cold-signing-key-file", tempAbsPath </> node </> "sophie/operator.skey"
      , "--operational-certificate-issue-counter-file", tempAbsPath </> node </> "sophie/operator.counter"
      , "--out-file", tempAbsPath </> node </> "sophie/node.cert"
      ]

  -- Generated node operator keys (cold, hot) and operational certs
  forM_ allNodes $ \node -> H.noteEachM_ . H.listDirectory $ tempAbsPath </> node </> "cole"

  -- Make some payment and stake addresses
  -- user1..n:       will own all the funds in the system, we'll set this up from
  --                 initial utxo the
  -- pool-owner1..n: will be the owner of the pools and we'll use their reward
  --                 account for pool rewards
  let userAddrs = ("user" <>) . show @Int <$> userPoolN
  let poolAddrs = ("pool-owner" <>) . show @Int <$> poolNodesN
  let addrs = userAddrs <> poolAddrs

  H.createDirectoryIfMissing $ tempAbsPath </> "addresses"

  wallets <- forM addrs $ \addr -> do
    let paymentSKey = tempAbsPath </> "addresses/" <> addr <> ".skey"
    let paymentVKey = tempAbsPath </> "addresses/" <> addr <> ".vkey"

    -- Payment address keys
    void $ H.execCli
      [ "address", "key-gen"
      , "--verification-key-file", paymentVKey
      , "--signing-key-file", paymentSKey
      ]

    -- Stake address keys
    void $ H.execCli
      [ "stake-address", "key-gen"
      , "--verification-key-file", tempAbsPath </> "addresses/" <> addr <> "-stake.vkey"
      , "--signing-key-file", tempAbsPath </> "addresses/" <> addr <> "-stake.skey"
      ]

    -- Payment addresses
    void $ H.execCli
      [ "address", "build"
      , "--payment-verification-key-file", tempAbsPath </> "addresses/" <> addr <> ".vkey"
      , "--stake-verification-key-file", tempAbsPath </> "addresses/" <> addr <> "-stake.vkey"
      , "--testnet-magic", show @Int testnetMagic
      , "--out-file", tempAbsPath </> "addresses/" <> addr <> ".addr"
      ]

    -- Stake addresses
    void $ H.execCli
      [ "stake-address", "build"
      , "--stake-verification-key-file", tempAbsPath </> "addresses/" <> addr <> "-stake.vkey"
      , "--testnet-magic", show @Int testnetMagic
      , "--out-file", tempAbsPath </> "addresses/" <> addr <> "-stake.addr"
      ]

    -- Stake addresses registration certs
    void $ H.execCli
      [ "stake-address", "registration-certificate"
      , "--stake-verification-key-file", tempAbsPath </> "addresses/" <> addr <> "-stake.vkey"
      , "--out-file", tempAbsPath </> "addresses/" <> addr <> "-stake.reg.cert"
      ]

    pure $ Wallet
      { paymentSKey
      , paymentVKey
      }

  -- user N will delegate to pool N
  forM_ userPoolN $ \n -> do
    -- Stake address delegation certs
    void $ H.execCli
      [ "stake-address", "delegation-certificate"
      , "--stake-verification-key-file", tempAbsPath </> "addresses/user" <> show @Int n <> "-stake.vkey"
      , "--cold-verification-key-file", tempAbsPath </> "node-pool" <> show @Int n </> "sophie/operator.vkey"
      , "--out-file", tempAbsPath </> "addresses/user" <> show @Int n <> "-stake.deleg.cert"
      ]

    H.createFileLink (tempAbsPath </> "addresses/pool-owner" <> show @Int n <> "-stake.vkey") (tempAbsPath </> "node-pool" <> show @Int n </> "owner.vkey")
    H.createFileLink (tempAbsPath </> "addresses/pool-owner" <> show @Int n <> "-stake.skey") (tempAbsPath </> "node-pool" <> show @Int n </> "owner.skey")

  -- Generated payment address keys, stake address keys,
  -- stake address regitration certs, and stake address delegatation certs
  H.noteEachM_ . H.listDirectory $ tempAbsPath </> "addresses"

  -- Next is to make the stake pool registration cert
  forM_ poolNodes $ \node -> do
    H.execCli
      [ "stake-pool", "registration-certificate"
      , "--testnet-magic", show @Int testnetMagic
      , "--pool-pledge", "0", "--pool-cost", "0", "--pool-margin", "0"
      , "--cold-verification-key-file", tempAbsPath </> node </> "sophie/operator.vkey"
      , "--vrf-verification-key-file", tempAbsPath </> node </> "sophie/vrf.vkey"
      , "--reward-account-verification-key-file", tempAbsPath </> node </> "owner.vkey"
      , "--pool-owner-stake-verification-key-file", tempAbsPath </> node </> "owner.vkey"
      , "--out-file", tempAbsPath </> node </> "registration.cert"
      ]

  -- Generated stake pool registration certs
  forM_ poolNodes $ \node -> H.assertIO . IO.doesFileExist $ tempAbsPath </> node </> "registration.cert"

  -- Now we'll construct one whopper of a transaction that does everything
  -- just to show off that we can, and to make the script shorter

  do
    -- We'll transfer all the funds to the user1, which delegates to pool1
    -- We'll register certs to:
    --  1. register the pool-owner1 stake address
    --  2. register the stake pool 1
    --  3. register the user1 stake address
    --  4. delegate from the user1 stake address to the stake pool
    txIn <- H.noteShow . S.strip =<< H.execCli
      [ "genesis", "initial-txin"
      , "--testnet-magic", show @Int testnetMagic
      , "--verification-key-file", tempAbsPath </> "sophie/utxo-keys/utxo1.vkey"
      ]

    H.note_ txIn

    user1Addr <- H.readFile $ tempAbsPath </> "addresses/user1.addr"

    void $ H.execCli
      [ "transaction", "build-raw"
      , "--invalid-hereafter", "1000"
      , "--fee", "0"
      , "--tx-in", txIn
      , "--tx-out",  user1Addr <> "+" <> show @Int maxSupply
      , "--certificate-file", tempAbsPath </> "addresses/pool-owner1-stake.reg.cert"
      , "--certificate-file", tempAbsPath </> "node-pool1/registration.cert"
      , "--certificate-file", tempAbsPath </> "addresses/user1-stake.reg.cert"
      , "--certificate-file", tempAbsPath </> "addresses/user1-stake.deleg.cert"
      , "--out-file", tempAbsPath </> "tx1.txbody"
      ]

  -- TODO: this will become the transaction to register the pool, etc.
  -- We'll need to pick the tx-in from the actual UTxO since it contains the txid,
  -- we'll have to query this via bcc-cli query utxo.

  {-  bcc-cli transaction build-raw \
          --invalid-hereafter 1000000 --fee 0 \
          --tx-in 67209bfcdf78f8cd86f649da75053a80fb9bb3fad68465554f9301c31b496c65#0 \
          --tx-out $(cat example/addresses/user1.addr)+450000000 \
          --certificate-file example/addresses/pool-owner1-stake.reg.cert \
          --certificate-file example/node-pool1/registration.cert \
          --certificate-file example/addresses/user1-stake.reg.cert \
          --certificate-file example/addresses/user1-stake.deleg.cert \
          --out-file example/register-pool.txbody
  -}

  {-  bcc-cli address convert \
          --cole-key-file example/cole/payment-keys.000.key \
          --signing-key-file example/cole/payment-keys.000-converted.key
  -}

  {-  bcc-cli transaction sign \
          --tx-body-file example/register-pool.txbody \
          --testnet-magic 42 \
          --signing-key-file example/cole/payment-keys.000-converted.key \
          --signing-key-file example/sophie/utxo-keys/utxo1.skey \
          --signing-key-file example/addresses/user1-stake.skey \
          --signing-key-file example/node-pool1/owner.skey \
          --signing-key-file example/node-pool1/sophie/operator.skey \
          --out-file example/register-pool.tx
  -}

  {-  bcc-cli transaction submit \
          --tx-file example/register-pool.tx --testnet-magic 42
  -}

  -- So we'll need to sign this with a bunch of keys:
  -- 1. the initial utxo spending key, for the funds
  -- 2. the user1 stake address key, due to the delegatation cert
  -- 3. the pool1 owner key, due to the pool registration cert
  -- 3. the pool1 operator key, due to the pool registration cert
  void $ H.execCli
    [ "transaction", "sign"
    , "--signing-key-file", tempAbsPath </> "sophie/utxo-keys/utxo1.skey"
    , "--signing-key-file", tempAbsPath </> "addresses/user1-stake.skey"
    , "--signing-key-file", tempAbsPath </> "node-pool1/owner.skey"
    , "--signing-key-file", tempAbsPath </> "node-pool1/sophie/operator.skey"
    , "--testnet-magic", show @Int testnetMagic
    , "--tx-body-file", tempAbsPath </> "tx1.txbody"
    , "--out-file", tempAbsPath </> "tx1.tx"
    ]

  -- Generated a signed 'do it all' transaction:
  H.assertIO . IO.doesFileExist $ tempAbsPath </> "tx1.tx"

  --------------------------------
  -- Launch cluster of three nodes

  bftSprockets <- forM bftNodes $ \node -> do
    dbDir <- H.noteShow $ tempAbsPath </> "db/" <> node
    nodeStdoutFile <- H.noteTempFile logDir $ node <> ".stdout.log"
    nodeStderrFile <- H.noteTempFile logDir $ node <> ".stderr.log"
    sprocket <- H.noteShow $ Sprocket tempBaseAbsPath (socketDir </> node)

    H.createDirectoryIfMissing dbDir
    H.createDirectoryIfMissing $ tempBaseAbsPath </> socketDir

    hNodeStdout <- H.openFile nodeStdoutFile IO.WriteMode
    hNodeStderr <- H.openFile nodeStderrFile IO.WriteMode

    H.diff (L.length (IO.sprocketArgumentName sprocket)) (<=) IO.maxSprocketArgumentNameLength

    portString <- fmap S.strip . H.readFile $ tempAbsPath </> node </> "port"

    (_, _, _, hProcess, _) <- H.createProcess =<<
      ( H.procNode
        [ "run"
        , "--config",  tempAbsPath </> "configuration.yaml"
        , "--topology",  tempAbsPath </> node </> "topology.json"
        , "--database-path", tempAbsPath </> node </> "db"
        , "--socket-path", IO.sprocketArgumentName sprocket
        , "--sophie-kes-key", tempAbsPath </> node </> "sophie/kes.skey"
        , "--sophie-vrf-key", tempAbsPath </> node </> "sophie/vrf.skey"
        , "--sophie-operational-certificate", tempAbsPath </> node </> "sophie/node.cert"
        , "--port",  portString
        , "--delegation-certificate",  tempAbsPath </> node </> "cole/delegate.cert"
        , "--signing-key", tempAbsPath </> node </> "cole/delegate.key"
        ] <&>
        ( \cp -> cp
          { IO.std_in = IO.CreatePipe
          , IO.std_out = IO.UseHandle hNodeStdout
          , IO.std_err = IO.UseHandle hNodeStderr
          , IO.cwd = Just tempBaseAbsPath
          }
        )
      )

    H.noteShowM_ $ H.getPid hProcess

    when (OS.os `L.elem` ["darwin", "linux"]) $ do
      H.onFailure . H.noteIO_ $ IO.readProcess "lsof" ["-iTCP:" <> portString, "-sTCP:LISTEN", "-n", "-P"] ""

    pure sprocket

  H.threadDelay 100000

  forM_ poolNodes $ \node -> do
    dbDir <- H.noteShow $ tempAbsPath </> "db/" <> node
    nodeStdoutFile <- H.noteTempFile logDir $ node <> ".stdout.log"
    nodeStderrFile <- H.noteTempFile logDir $ node <> ".stderr.log"
    sprocket <- H.noteShow $ Sprocket tempBaseAbsPath (socketDir </> node)

    H.createDirectoryIfMissing dbDir
    H.createDirectoryIfMissing $ tempBaseAbsPath </> socketDir

    hNodeStdout <- H.openFile nodeStdoutFile IO.WriteMode
    hNodeStderr <- H.openFile nodeStderrFile IO.WriteMode

    H.diff (L.length (IO.sprocketArgumentName sprocket)) (<=) IO.maxSprocketArgumentNameLength

    portString <- fmap S.strip . H.readFile $ tempAbsPath </> node </> "port"

    void $ H.createProcess =<<
      ( H.procNode
        [ "run"
        , "--config", tempAbsPath </> "configuration.yaml"
        , "--topology", tempAbsPath </> node </> "topology.json"
        , "--database-path", tempAbsPath </> node </> "db"
        , "--socket-path", IO.sprocketArgumentName sprocket
        , "--sophie-kes-key", tempAbsPath </> node </> "sophie/kes.skey"
        , "--sophie-vrf-key", tempAbsPath </> node </> "sophie/vrf.skey"
        , "--sophie-operational-certificate", tempAbsPath </> node </> "sophie/node.cert"
        , "--host-addr", ifaceAddress
        , "--port",  portString
        ] <&>
        ( \cp -> cp
          { IO.std_in = IO.CreatePipe
          , IO.std_out = IO.UseHandle hNodeStdout
          , IO.std_err = IO.UseHandle hNodeStderr
          , IO.cwd = Just tempBaseAbsPath
          }
        )
      )

    when (OS.os `L.elem` ["darwin", "linux"]) $ do
      H.onFailure . H.noteIO_ $ IO.readProcess "lsof" ["-iTCP:" <> portString, "-sTCP:LISTEN", "-n", "-P"] ""

  now <- H.noteShowIO DTC.getCurrentTime
  deadline <- H.noteShow $ DTC.addUTCTime 90 now

  forM_ allNodes $ \node -> do
    sprocket <- H.noteShow $ Sprocket tempBaseAbsPath (socketDir </> node)
    _spocketSystemNameFile <- H.noteShow $ IO.sprocketSystemName sprocket
    H.waitByDeadlineM deadline $ H.doesSprocketExist sprocket

  forM_ allNodes $ \node -> do
    nodeStdoutFile <- H.noteTempFile logDir $ node <> ".stdout.log"
    H.assertByDeadlineIO deadline $ IO.fileContains "until genesis start time at" nodeStdoutFile
    H.assertByDeadlineIO deadline $ IO.fileContains "Chain extended, new tip" nodeStdoutFile

  H.noteShowIO_ DTC.getCurrentTime

  return TestnetRuntime
    { configurationFile
    , testnetMagic
    , allNodes
    , bftSprockets
    , wallets
    }
