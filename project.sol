// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract StudyGroupIncentives is ERC20, Ownable, ReentrancyGuard {
    struct Session {
        string topic;
        uint256 timestamp;
        uint256 duration;
        uint256 rewardAmount;
        bool isActive;
    }

    struct Attendance {
        bool hasAttended;
        bool hasClaimedReward;
    }

    mapping(uint256 => Session) public sessions;
    mapping(uint256 => mapping(address => Attendance)) public attendanceRecord;
    uint256 public sessionCounter;
    uint256 public minAttendanceTime;
    mapping(address => bool) public moderators;

    event SessionCreated(uint256 indexed sessionId, string topic, uint256 timestamp);
    event AttendanceMarked(uint256 indexed sessionId, address indexed student);
    event RewardClaimed(uint256 indexed sessionId, address indexed student, uint256 amount);
    event ModeratorAdded(address indexed moderator);
    event ModeratorRemoved(address indexed moderator);

    constructor(
        string memory name, 
        string memory symbol,
        address initialOwner
    ) 
        ERC20(name, symbol) 
        Ownable(initialOwner)
    {
        minAttendanceTime = 45 minutes;
        _mint(initialOwner, 1000000 * 10 ** decimals()); // Initial supply
    }

    modifier onlyModerator() {
        require(moderators[msg.sender] || owner() == msg.sender, "Not authorized");
        _;
    }

    function addModerator(address moderator) external onlyOwner {
        moderators[moderator] = true;
        emit ModeratorAdded(moderator);
    }

    function removeModerator(address moderator) external onlyOwner {
        moderators[moderator] = false;
        emit ModeratorRemoved(moderator);
    }

    function createSession(
        string memory topic,
        uint256 timestamp,
        uint256 duration,
        uint256 rewardAmount
    ) external onlyModerator {
        require(timestamp > block.timestamp, "Invalid session time");
        require(duration >= minAttendanceTime, "Session too short");
        
        sessionCounter++;
        sessions[sessionCounter] = Session({
            topic: topic,
            timestamp: timestamp,
            duration: duration,
            rewardAmount: rewardAmount,
            isActive: true
        });

        emit SessionCreated(sessionCounter, topic, timestamp);
    }

    function markAttendance(uint256 sessionId) external nonReentrant {
        Session storage session = sessions[sessionId];
        require(session.isActive, "Session does not exist");
        require(block.timestamp >= session.timestamp, "Session has not started");
        require(block.timestamp <= session.timestamp + session.duration, "Session has ended");
        require(!attendanceRecord[sessionId][msg.sender].hasAttended, "Already marked attendance");

        attendanceRecord[sessionId][msg.sender].hasAttended = true;
        emit AttendanceMarked(sessionId, msg.sender);
    }

    function claimReward(uint256 sessionId) external nonReentrant {
        require(attendanceRecord[sessionId][msg.sender].hasAttended, "No attendance record");
        require(!attendanceRecord[sessionId][msg.sender].hasClaimedReward, "Reward already claimed");
        require(sessions[sessionId].isActive, "Invalid session");
        require(block.timestamp > sessions[sessionId].timestamp + sessions[sessionId].duration, "Session not ended");

        attendanceRecord[sessionId][msg.sender].hasClaimedReward = true;
        _mint(msg.sender, sessions[sessionId].rewardAmount);

        emit RewardClaimed(sessionId, msg.sender, sessions[sessionId].rewardAmount);
    }

    function getSessionDetails(uint256 sessionId) external view returns (
        string memory topic,
        uint256 timestamp,
        uint256 duration,
        uint256 rewardAmount,
        bool isActive
    ) {
        Session storage session = sessions[sessionId];
        return (
            session.topic,
            session.timestamp,
            session.duration,
            session.rewardAmount,
            session.isActive
        );
    }
}