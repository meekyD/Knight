# Medieval Kingdom Defense Contract

A Clarity smart contract for the Stacks blockchain that implements a medieval-themed knight deployment and fortress defense system. Players can deploy knights to defend fortresses and earn glory coins based on their contributions.

## 🏰 Contract Overview

The Medieval Kingdom Defense Contract allows players to:
- Deploy knights to defend various fortresses across the kingdom
- Earn glory coins based on battle participation and fortress difficulty
- Withdraw knights and claim rewards
- Participate in emergency retreats during sieges

## 🎮 Game Mechanics

### Fortresses
Each fortress has the following properties:
- **Name**: Descriptive name (max 20 characters)
- **Danger Level**: Difficulty rating (1-10)
- **Glory Multiplier**: Reward multiplier (50-500%)
- **Defenders**: Current number of knights defending
- **Active Status**: Whether the fortress accepts new deployments

### Knight Deployment
- Knights cost 1 glory coin each to deploy
- Knights earn glory over time based on:
  - Number of knights deployed
  - Fortress difficulty (danger level)
  - Glory multiplier
  - Time spent defending (blocks)
  - Total defenders at the fortress

### Glory Calculation
```
Glory Earned = (Knights Deployed × Battles Fought × Glory Per Battle × Glory Multiplier) ÷ (Total Fortress Defenders × 100)
```

## 🚀 Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js and npm
- Basic understanding of Clarity smart contracts

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd medieval-kingdom-defense
```

2. Install dependencies:
```bash
npm install
```

3. Check the contract:
```bash
clarinet check
```

4. Run tests:
```bash
clarinet test
```

### Deployment

1. Deploy to testnet:
```bash
clarinet deploy --testnet
```

2. Initialize the kingdom:
```clarity
(contract-call? .knight establish-kingdom)
```

## 📋 Contract Functions

### Public Functions

#### `establish-kingdom`
Initializes the contract with default fortresses and mints initial glory coins to the king.
```clarity
(establish-kingdom)
```

#### `build-fortress`
**King Only** - Creates a new fortress with specified parameters.
```clarity
(build-fortress "Castle Name" u5 u150) ;; name, danger-level, glory-multiplier
```

#### `deploy-knights`
Deploy knights to defend a specific fortress.
```clarity
(deploy-knights u0 u10) ;; fortress-id, knight-count
```

#### `withdraw-knights`
Withdraw knights from a fortress and claim earned glory.
```clarity
(withdraw-knights u0 u5) ;; fortress-id, knight-count
```

#### `emergency-retreat`
Retreat all knights during siege mode (with penalty).
```clarity
(emergency-retreat u0) ;; fortress-id
```

#### `declare-siege`
**King Only** - Toggle siege mode on/off.
```clarity
(declare-siege true) ;; activate siege mode
```

### Read-Only Functions

#### `get-knight-deployment`
Get deployment information for a specific knight and fortress.
```clarity
(get-knight-deployment 'SP1234... u0)
```

#### `get-fortress-info`
Get detailed information about a fortress.
```clarity
(get-fortress-info u0)
```

#### `get-kingdom-stats`
Get overall kingdom statistics.
```clarity
(get-kingdom-stats)
```

## 🛡️ Security Features

### Input Validation
- Fortress names must not be empty
- Danger levels capped at 10
- Glory multipliers between 50-500
- Fortress IDs limited to prevent overflow attacks
- Knight counts must be positive

### Access Control
- Only the king can build fortresses and declare sieges
- Players can only withdraw their own knights
- Contract ownership is immutable

### Error Handling
The contract includes comprehensive error codes:
- `ERR-NOT-KING` (101): Unauthorized access
- `ERR-INVALID-KNIGHTS` (102): Invalid knight count
- `ERR-NO-KNIGHTS-DEPLOYED` (103): No knights to withdraw
- `ERR-FORTRESS-NOT-FOUND` (104): Fortress doesn't exist
- `ERR-FORTRESS-INACTIVE` (105): Fortress is inactive
- `ERR-INVALID-DANGER-LEVEL` (106): Danger level out of bounds
- `ERR-INVALID-GLORY-MULTIPLIER` (107): Glory multiplier out of bounds
- `ERR-FORTRESS-ID-TOO-HIGH` (108): Fortress ID exceeds maximum
- `ERR-EMPTY-NAME` (109): Fortress name is empty

## 🏗️ Default Fortresses

The contract initializes with three default fortresses:

1. **Archer Tower**
   - Danger Level: 2
   - Glory Multiplier: 90%

2. **Knight Barracks**
   - Danger Level: 5
   - Glory Multiplier: 130%

3. **Dragon Lair**
   - Danger Level: 8
   - Glory Multiplier: 180%

## 🎯 Strategy Tips

1. **Higher Risk, Higher Reward**: Dragon Lair offers the highest glory multiplier but requires more investment
2. **Timing Matters**: Deploy early to maximize battle time and glory earnings
3. **Diversification**: Spread knights across multiple fortresses to balance risk
4. **Siege Awareness**: Monitor siege mode status - retreats incur 15% penalty
5. **Competition**: More defenders at a fortress means lower individual rewards

## 🧪 Testing

The contract includes comprehensive test coverage for:
- Fortress creation and validation
- Knight deployment and withdrawal
- Glory calculation accuracy
- Error handling scenarios
- Access control mechanisms

Run tests with:
```bash
clarinet test
```

## 📊 Game Balance

### Economic Model
- **Initial King Treasury**: 500,000 glory coins
- **Deployment Cost**: 1 glory coin per knight
- **Retreat Penalty**: 15% of deployed knights
- **Glory Per Battle**: 8 coins base rate

### Validation Limits
- **Max Danger Level**: 10
- **Glory Multiplier Range**: 50% - 500%
- **Max Fortress ID**: 1,000
- **Fortress Name Length**: 20 characters

## 🔧 Development

### Project Structure
```
├── contracts/
│   └── Knight.clar          # Main contract
├── tests/
│   └── knight_test.ts       # Test suite
├── Clarinet.toml           # Clarinet configuration
└── README.md               # This file
```
