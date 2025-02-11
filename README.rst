.. raw:: html

  <p align="center">
    <a href="https://github.com/The-Blockchain-Company/bcc-node/releases"><img src="https://img.shields.io/github/release-pre/The-Blockchain-Company/bcc-node.svg?style=for-the-badge" /></a>
    <a href="https://buildkite.com/The-Blockchain-Company/bcc-node"><img src="https://img.shields.io/buildkite/a978cbb4def7018be3d0a004127da356f4db32f1c318c1a48a/master?label=BUILD&style=for-the-badge"/></a>
  </p>

  <table align="center">
    <tr><td colspan="2" align="center">Github Actions</td></tr>
    <tr>
      <td>
        <a href="https://github.com/The-Blockchain-Company/bcc-node/actions/workflows/haskell.yml"><img alt="GitHub Workflow Status (master)" src="https://img.shields.io/github/workflow/status/The-Blockchain-Company/bcc-node/Haskell%20CI/master" /></a>
        <a href="https://github.com/The-Blockchain-Company/bcc-node/actions/workflows/haskell.yml"><img alt="GitHub Workflow Status (branch)" src="https://img.shields.io/github/workflow/status/The-Blockchain-Company/bcc-node/Haskell%20CI/nightly?label=nightly" /></a>
      </td>
    </tr>
  </table>

*************************
``bcc-node`` Overview
*************************

Integration of the `ledger <https://github.com/The-Blockchain-Company/bcc-ledger-specs>`_, `consensus <https://github.com/The-Blockchain-Company/shardagnostic-network/tree/master/shardagnostic-consensus>`_,
`networking <https://github.com/The-Blockchain-Company/shardagnostic-network/tree/master/shardagnostic-network>`_ and
`node shell <https://github.com/The-Blockchain-Company/bcc-shell>`_ repositories.

`Logging <https://github.com/The-Blockchain-Company/tbco-monitoring-framework>`_ is provided as a
`feature <https://github.com/The-Blockchain-Company/bcc-shell/blob/master/app/Bcc/Shell/Features/Logging.hs>`_ by the node shell to the other packages.

- The bcc-node is the top level for the node and
  aggregates the other components from other packages: consensus, ledger and
  networking, with configuration, CLI, logging and monitoring.

- The node no longer incorporates wallet or explorer functionality. The wallet
  backend and explorer backend are separate components that run in separate
  external processes that communicate with the node via local IPC.

Network Configuration, Genesis and Topology Files
=================================================

The latest supported networks can be found at `<https://hydra.tbco.io/job/Bcc/bcc-node/bcc-deployment/latest-finished/download/1/index.html>`_

How to build
============

Documentation for building the node can be found `here <https://docs.bcc.org/getting-started/installing-the-bcc-node>`_.

Linux Executable
==================

You can download the latest version of ``bcc-node`` and ``bcc-cli``:

* `linux <https://hydra.tbco.io/job/Bcc/bcc-node/bcc-node-linux/latest-finished>`_
* `win64 <https://hydra.tbco.io/job/Bcc/bcc-node/bcc-node-win64/latest-finished>`_
* `macos <https://hydra.tbco.io/job/Bcc/bcc-node/bcc-node-macos/latest-finished>`_

Windows Executable
==================

Download
--------

You can download `here <https://hydra.tbco.io/job/Bcc/bcc-node/bcc-node-win64/latest-finished>`_.

Instructions
------------

The download includes bcc-node.exe and a .dll. To run the node with bcc-node run you need to reference a few files and directories as arguments. These can be copied from the bcc-node repo into the executables directory. The command to run the node on mainnet looks like this:

.. code-block:: console

    bcc-node.exe run --topology ./mainnet-topology.json --database-path ./state --port 3001 --config ./configuration-mainnet.yaml --socket-path \\.\pipe\bcc-node

Docker image
============

You can pull the docker image with the latest version of bcc-node from `here <https://hub.docker.com/r/tbco/bcc-node>`_.

.. code-block:: console

    docker pull tbco/bcc-node

``bcc-node``
================
This refers to the client that is used for running a node.

The general synopsis is as follows:

.. code-block:: console

   Usage: bcc-node run [--topology FILEPATH] [--database-path FILEPATH]
                           [--socket-path FILEPATH]
                           [--cole-delegation-certificate FILEPATH]
                           [--cole-signing-key FILEPATH]
                           [--sophie-kes-key FILEPATH]
                           [--sophie-vrf-key FILEPATH]
                           [--sophie-operational-certificate FILEPATH]
                           [--host-addr IPV4-ADDRESS]
                           [--host-ipv6-addr IPV6-ADDRESS]
                           [--port PORT]
                           [--config NODE-CONFIGURATION] [--validate-db]
     Run the node.

* ``--topology`` - Filepath to a topology file describing which peers the node should connect to.

* ``--database-path`` - Path to the blockchain database.

* ``--cole-delegation-certificate`` - Optional path to the Cole delegation certificate. The delegation certificate allows the delegator (the issuer of said certificate) to give his/her own block signing rights to somebody else (the delegatee). The delegatee can then sign blocks on behalf of the delegator.

* ``--cole-signing-key`` - Optional path to the Cole signing key.

* ``--sophie-signing-key`` - Optional path to the Sophie signing key.

* ``--sophie-kes-key`` - Optional path to the Sophie KES signing key.

* ``--sophie-vrf-key`` - Optional path to the Sophie VRF signing key.

* ``--sophie-operational-certificate`` - Optional path to the Sophie operational certificate.

* ``--socket-path`` - Path to the socket file.

* ``--host-addr`` - Optionally specify your node's IPv4 address.

* ``--host-ipv6-addr`` - Optionally specify your node's IPv6 address.

* ``--port`` - Specify which port to assign to the node.

* ``--config`` - Specify the filepath to the config ``.yaml`` file. This file is responsible for all the other node's required settings. See examples in ``configuration`` (e.g. `config-0.yaml <configuration/defaults/simpleview/config-0.yaml>`_).

* ``--validate-db`` - Flag to revalidate all on-disk database files

Configuration ``.yaml`` files
=============================

The ``--config`` flag points to a ``.yaml`` file that is responsible to configuring the logging & other important settings for the node. E.g. see the Cole mainnet configuration in this
`configuration.yaml <https://github.com/The-Blockchain-Company/bcc-node/blob/master/configuration/defaults/cole-mainnet/configuration.yaml>`_.
Some of the more important settings are as follows:

* ``Protocol: RealPBFT`` -- Protocol the node will execute

* ``RequiresNetworkMagic``: RequiresNoMagic -- Used to distinguish between mainnet (``RequiresNoMagic``) and testnets (``RequiresMagic``)


Logging
========

Logs are output to the ``logs/`` dir.

Profiling & statistics
======================

Profiling data and RTS run stats are stored in the ``profile/`` dir.

Please see ``scripts/README.md`` for how to obtain profiling information using the scripts.

Scripts
=======

Please see ``scripts/README.md`` for information on the various scripts.

``bcc-cli``
===============

A CLI utility to support a variety of key material operations (genesis, migration, pretty-printing..) for different system generations.
Usage documentation can be found at ``bcc-cli/README.md``.

The general synopsis is as follows:

.. code-block:: console

   Usage: bcc-cli (Era based commands | Cole specific commands | Miscellaneous commands)

> NOTE: the exact invocation command depends on the environment.  If you have only built ``bcc-cli``, without installing it, then you have to prepend ``cabal run -- ``
before ``bcc-cli``.  We henceforth assume that the necessary environment-specific adjustment has been made, so we only mention ``bcc-cli``.

The subcommands are subdivided in groups, and their full list can be seen in the output of ``bcc-cli --help``.

All subcommands have help available.  For example:

.. code-block:: console

   cabal run -- bcc-cli -- cole key migrate-delegate-key-from --help

   bcc-cli -- cole key migrate-delegate-key-from
   Usage: bcc-cli cole key migrate-delegate-key-from --from FILEPATH
                                                          --to FILEPATH
     Migrate a delegate key from an older version.


   Available options:
     --cole-legacy-formats   Cole/bcc-sl formats and compatibility
     --cole-formats          Cole era formats and compatibility
     --from FILEPATH          Signing key file to migrate.
     --to FILEPATH            Non-existent file to write the signing key to.
     -h,--help                Show this help text


Genesis operations
==================

Generation
----------

The Cole genesis generation operations will create a directory that contains:

* ``genesis.json``:
  The genesis JSON file itself.

* ``avvm-seed.*.seed``:
  Bcc Voucher Vending Machine seeds (secret). Affected by ``--avvm-entry-count`` and ``--avvm-entry-balance``.

* ``delegate-keys.*.key``:
  Delegate private keys. Affected by: ``--n-delegate-addresses``.

* ``delegation-cert.*.json``:
  Delegation certificates. Affected by: ``--n-delegate-addresses``.

* ``genesis-keys.*.key``:
  Genesis stake private keys. Affected by: ``--n-delegate-addresses``, ``--total-balance``.

* ``poor-keys.*.key``:
  Non-delegate private keys with genesis UTxO. Affected by: ``--n-poor-addresses``, ``--total-balance``.

More details on the Cole Genesis ``JSON`` file can be found in ``docs/reference/cole-genesis.md``

 Cole genesis delegation and related concepts are described in detail in:

  `<https://hydra.tbco.io/job/Bcc/bcc-ledger-specs/coleLedgerSpec/latest/download-by-type/doc-pdf/ledger-spec>`_

The canned ``scripts/benchmarking/genesis.sh`` example provides a nice set of defaults and
illustrates available options.

Key operations
==============

Note that key operations do not support password-protected keys.

Signing key generation & verification key extraction
----------------------------------------------------

Signing keys can be generated using the ``keygen`` subcommand.

Extracting a verification key out of the signing key is performed by the ``to-verification`` subcommand.

Delegate key migration
----------------------

In order to continue using a delegate key from the Cole Legacy era in the new implementation,
it needs to be migrated over, which is done by the ``migrate-delegate-key-from`` subcommand:

.. code-block:: console

  $ cabal v2-run -- bcc-cli cole key migrate-delegate-key-from
          --from key0.sk --to key0Converted.sk

Signing key queries
-------------------

One can gather information about a signing key's properties through the ``signing-key-public``
and ``signing-key-address`` subcommands (the latter requires the network magic):

.. code-block:: console

   $ cabal v2-run -- bcc-cli cole key signing-key-public --cole-formats --secret key0.sk

   public key hash: a2b1af0df8ca764876a45608fae36cf04400ed9f413de2e37d92ce04
   public key: sc4pa1pAriXO7IzMpByKo4cG90HCFD465Iad284uDYz06dHCqBwMHRukReQ90+TA/vQpj4L1YNaLHI7DS0Z2Vg==

   $ cabal v2-run -- bcc-cli signing-key-address --cole-formats --secret key0.pbft --testnet-magic 42

   2cWKMJemoBakxhXgZSsMteLP9TUvz7owHyEYbUDwKRLsw2UGDrG93gPqmpv1D9ohWNddx
   VerKey address with root e5a3807d99a1807c3f161a1558bcbc45de8392e049682df01809c488, attributes: AddrAttributes { derivation path: {} }

Transactions
============

Creation
--------

Transactions can be created via the  ``issue-genesis-utxo-expenditure`` & ``issue-utxo-expenditure`` commands.

The easiest way to create a transaction is via the ``scripts/benchmarking/issue-genesis-utxo-expenditure.sh`` script as follows:

``./scripts/benchmarking/issue-genesis-utxo-expenditure.sh transaction_file``

NB: This by default creates a transaction based on ``configuration/defaults/liveview/config-0.yaml``

If you do not have a ``genesis_file`` you can run ``scripts/benchmarking/genesis.sh`` which will create an example ``genesis_file`` for you.
The script ``scripts/benchmarking/issue-genesis-utxo-expenditure.sh`` has defaults for all the requirements of the ``issue-genesis-utxo-expenditure`` command.

Submission
----------

The ``submit-tx`` subcommand provides the option of submitting a pre-signed
transaction, in its raw wire format (see GenTx for Cole transactions).

The canned ``scripts/benchmarking/submit-tx.sh`` script will submit the supplied transaction to a testnet
launched by ``scripts/benchmarking/sophie-testnet-liveview.sh`` script.

Issuing UTxO expenditure (genesis and regular)
----------------------------------------------

To make a transaction spending UTxO, you can either use the:

  - ``issue-genesis-utxo-expenditure``, for genesis UTxO
  - ``issue-utxo-expenditure``, for normal UTxO

subcommands directly, or, again use canned scripts that will make transactions tailored
for the aforementioned testnet cluster:

  - ``scripts/benchmarking/issue-genesis-utxo-expenditure.sh``.
  - ``scripts/benchmarking/issue-utxo-expenditure.sh``.

The script requires the target file name to write the transaction to, input TxId
(for normal UTxO), and optionally allows specifying the source txin output index,
source and target signing keys and entropic value to send.

The target address defaults to the 1-st richman key (``configuration/delegate-keys.001.key``)
of the testnet, and entropic amount is almost the entirety of its funds.

Local node queries
==================

You can query the tip of your local node via the ``get-tip`` command as follows

1. Open `tmux`
2. Run ``cabal build bcc-node``
3. Run ``./scripts/lite/sophie-testnet.sh example``
4. Run ``export BCC_NODE_SOCKET_PATH=/bcc-node/example/socket/node-1-socket
4. ``cabal exec bcc-cli -- get-tip --testnet-magic 42``

You will see output from stdout in this format:

.. code-block:: console

   Current tip:
   Block hash: 4ab21a10e1b25e39
   Slot: 6
   Block number: 5

Update proposals
================

Update proposal creation
------------------------

A Cole update proposal can be created as follows:

.. code-block:: console

   bcc-cli -- cole governance
                  create-update-proposal
                    (--mainnet | --testnet-magic NATURAL)
                    --signing-key FILEPATH
                    --protocol-version-major WORD16
                    --protocol-version-minor WORD16
                    --protocol-version-alt WORD8
                    --application-name STRING
                    --software-version-num WORD32
                    --system-tag STRING
                    --installer-hash HASH
                    --filepath FILEPATH
                  ..

The mandatory arguments are ``--mainnet | --testnet-magic``, ``signing-key``, ``protocol-version-major``, ``protocol-version-minor``, ``protocol-version-alt``, ``application-name``, ``software-version-num``, ``system-tag``, ``installer-hash`` and ``filepath``.

The remaining arguments are optional parameters you want to update in your update proposal.

You can also check your proposal's validity using the `validate-cbor` command. See: `Validate CBOR files`_.

See the `Cole specification <https://hydra.tbco.io/job/Bcc/bcc-ledger-specs/coleLedgerSpec/latest/download-by-type/doc-pdf/ledger-spec>`_
for more details on update proposals.

Update proposal submission
--------------------------

You can submit your proposal using the ``submit-update-proposal`` command.

Example:

.. code-block:: console

   bcc-cli -- cole governance
               submit-update-proposal
               --config configuration/defaults/mainnet/configuration.yaml
               (--mainnet | --testnet-magic NATURAL)
               --filepath my-update-proposal

See the `Cole specification <https://hydra.tbco.io/job/Bcc/bcc-ledger-specs/coleLedgerSpec/latest/download-by-type/doc-pdf/ledger-spec>`_
for more deatils on update proposals.

Update proposal voting
======================

You can create and submit cole update proposal votes with the ``create-proposal-vote`` & ``submit-proposal-vote`` commands. The following are two example commands:


Cole vote creation:

.. code-block:: console

   cabal exec bcc-cli -- cole governance create-proposal-vote
                          (--mainnet | --testnet-magic NATURAL)
                          --signing-key configuration/defaults/liveview/genesis/delegate-keys.000.key
                          --proposal-filepath ProtocolUpdateProposalFile
                          --vote-yes
                          --output-filepath UpdateProposalVoteFile

Cole vote submission:

.. code-block:: console

   cabal exec bcc-cli -- cole governance submit-proposal-vote
                          (--mainnet | --testnet-magic NATURAL)
                          --filepath UpdateProposalVoteFile

Development
===========

GHCID
-----

run *ghcid* with: ``ghcid -c "cabal repl exe:bcc-node --reorder-goals"``

Haskell Language Server
-----------------------

When using Haskell Langague Server with Visual Studio Code, you may find that
`HLINT annotations are ignored<https://github.com/haskell/haskell-language-server/issues/638>`.

To work around this, you may run the script `./scripts/reconfigure-hlint.sh` to generate a `.hlint.yaml`
file with HLINT ignore rules derived from the source code.

Testing
========

``bcc-node`` is essentially a container which implements several components such networking, consensus, and storage. These components have individual test coverage. The node goes through integration and release testing by Devops/QA while automated CLI tests are ongoing alongside development.

Developers on ``bcc-node`` can `launch their own testnets <doc/getting-started/launching-a-testnet.md>`_ or `run the chairman tests <doc/getting-started/running-chairman-tests.md>`_ locally.

Chairman tests
--------------

Debugging
=========

Pretty printing CBOR encoded files
----------------------------------

It may be useful to print the on chain representations of blocks, delegation certificates, txs and update proposals. There are two commands that do this (for any cbor encoded file):

To pretty print as CBOR:
``cabal exec bcc-cli -- pretty-print-cbor --filepath CBOREncodedFile``

Validate CBOR files
-------------------

You can validate Cole era blocks, delegation certificates, txs and update proposals with the ``validate-cbor`` command.

``cabal exec bcc-cli -- validate-cbor --cole-block 21600 --filepath CBOREncodedColeBlockFile``


Native Tokens 
=======================================

Native tokens is a new feature that enables the transacting of multi-assets on Bcc. Native tokens are now supported on mainnet and users can transact with bcc, and an unlimited number of user-defined (custom) tokens natively.

To help you get started we have compiled a handy list of resources:

`Bcc Forum discussion <https://forum.bcc.org/c/developers/bcc-tokens/150>`_

`Documentation for native tokens <https://docs.bcc.org/native-tokens/learn>`_

You can also read more about `native tokens and how they compare to bcc and ERC20 <https://github.com/The-Blockchain-Company/bcc-ledger-specs/blob/master/doc/explanations/features.rst>`_. Browse native tokens created on the Bcc blockchain and see their transactions in an interactive dashboard that allows filtering and searching: nativetokens.da.iogservices.io.

API Documentation
=================
The API documentation is published `here <https://The-Blockchain-Company.github.io/bcc-node/>`_.

The documentation is built with each push, but is only published from `master` branch.  In order to
test if the documentation is working, build the documentation locally with `./scripts/haddocs.sh` and
open `haddocks/index.html` in the browser.
