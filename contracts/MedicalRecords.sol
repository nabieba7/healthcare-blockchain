// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MedicalRecords {
    // --- Admin and roles ---
    address public admin;

    enum Role { None, Doctor } // Extendable if needed
    mapping(address => Role) public roles;

    event RoleAssigned(address indexed actor, Role role);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyDoctor() {
        require(roles[msg.sender] == Role.Doctor, "Only doctor");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function assignDoctor(address doctor) external onlyAdmin {
        roles[doctor] = Role.Doctor;
        emit RoleAssigned(doctor, Role.Doctor);
    }

    // --- Core data models ---

    struct Patient {
        address walletAddress;
        string name;
        uint256 dateOfBirth; // unix timestamp
        bool exists;
    }

    struct MedicalRecord {
        uint256 recordId;
        string diagnosis;
        string treatment;
        string medications;
        uint256 date;          // unix timestamp (createdAt)
        address doctorAddress; // creator (doctor or patient)
        string hospital;
    }

    struct AccessControl {
        address authorizedDoctor;
        uint256 accessUntil; // unix timestamp
        bool isActive;
    }

    struct EmergencyAccess {
        address emergencyContact;
        uint256 grantedAt; // time granted; used for 24h window
        bool isActive;
    }

    // --- Storage ---

    mapping(address => Patient) public patients;
    address[] public patientAddresses;

    mapping(address => MedicalRecord[]) private patientRecords;
    mapping(address => AccessControl[]) private patientAccessControls;
    mapping(address => EmergencyAccess) private emergencyAccesses;

    // --- Events ---

    event PatientRegistered(address indexed patientAddress, string name);
    event RecordAdded(address indexed patient, uint256 recordId, address indexed by);
    event AccessGranted(address indexed patient, address indexed doctor, uint256 until);
    event EmergencyAccessGranted(address indexed patient, address indexed contact);
    event EmergencyAccessUsed(address indexed patient, address indexed contact);
    event AccessRevoked(address indexed patient, address indexed doctor);

    // --- Patient management ---

    function registerPatient(
        address _patientAddress,
        string memory _name,
        uint256 _dateOfBirth
    ) public onlyAdmin {
        require(!patients[_patientAddress].exists, "Patient already registered");

        patients[_patientAddress] = Patient({
            walletAddress: _patientAddress,
            name: _name,
            dateOfBirth: _dateOfBirth,
            exists: true
        });

        patientAddresses.push(_patientAddress);
        emit PatientRegistered(_patientAddress, _name);
    }

    // --- Records ---

    function addMedicalRecord(
        address _patientAddress,
        string memory _diagnosis,
        string memory _treatment,
        string memory _medications,
        string memory _hospital
    ) public {
        require(patients[_patientAddress].exists, "Patient does not exist");

        // Patient can add their own record; Doctor must have consent
        bool allowed = (msg.sender == _patientAddress) || (hasAccess(_patientAddress, msg.sender) && roles[msg.sender] == Role.Doctor);
        require(allowed, "No access to patient records");

        uint256 newRecordId = patientRecords[_patientAddress].length;

        patientRecords[_patientAddress].push(MedicalRecord({
            recordId: newRecordId,
            diagnosis: _diagnosis,
            treatment: _treatment,
            medications: _medications,
            date: block.timestamp,
            doctorAddress: msg.sender,
            hospital: _hospital
        }));

        emit RecordAdded(_patientAddress, newRecordId, msg.sender);
    }

    // --- Access management ---

    function grantAccess(address _doctorAddress, uint256 _accessDuration) public {
        require(patients[msg.sender].exists, "Only patients can grant access");
        require(roles[_doctorAddress] == Role.Doctor, "Target is not a doctor");
        require(_accessDuration > 0, "Duration must be > 0");

        uint256 accessUntil = block.timestamp + _accessDuration;

        patientAccessControls[msg.sender].push(AccessControl({
            authorizedDoctor: _doctorAddress,
            accessUntil: accessUntil,
            isActive: true
        }));

        emit AccessGranted(msg.sender, _doctorAddress, accessUntil);
    }

    function revokeAccess(address _doctorAddress) public {
        AccessControl[] storage accesses = patientAccessControls[msg.sender];
        for (uint256 i = 0; i < accesses.length; i++) {
            if (accesses[i].authorizedDoctor == _doctorAddress && accesses[i].isActive) {
                accesses[i].isActive = false;
                emit AccessRevoked(msg.sender, _doctorAddress);
                break;
            }
        }
    }

    // View helper: does doctor have active, unexpired consent
    function hasAccess(address _patientAddress, address _doctorAddress) public view returns (bool) {
        if (_patientAddress == _doctorAddress) return true; // patient viewing own data

        AccessControl[] memory accesses = patientAccessControls[_patientAddress];
        for (uint256 i = 0; i < accesses.length; i++) {
            if (
                accesses[i].authorizedDoctor == _doctorAddress &&
                accesses[i].isActive &&
                accesses[i].accessUntil > block.timestamp
            ) {
                return true;
            }
        }
        return false;
    }

    // --- Emergency access (24h window) ---

    function grantEmergencyAccess(address _emergencyContact) public {
        require(patients[msg.sender].exists, "Only patients can grant emergency access");
        require(_emergencyContact != address(0), "Invalid contact");

        emergencyAccesses[msg.sender] = EmergencyAccess({
            emergencyContact: _emergencyContact,
            grantedAt: block.timestamp,
            isActive: true
        });

        emit EmergencyAccessGranted(msg.sender, _emergencyContact);
    }

    function useEmergencyAccess(address _patientAddress) public {
        EmergencyAccess memory access = emergencyAccesses[_patientAddress];
        require(access.isActive, "No emergency access");
        require(access.emergencyContact == msg.sender, "Not authorized");

        // Enforce 24-hour window from grant time
        require(block.timestamp <= access.grantedAt + 24 hours, "Emergency window expired");

        emit EmergencyAccessUsed(_patientAddress, msg.sender);
        // Note: actual record retrieval still goes through getPatientRecords with checks below
    }

    // --- Record retrieval ---

    function getPatientRecords(address _patientAddress) public view returns (MedicalRecord[] memory) {
        bool allowed =
            (msg.sender == _patientAddress) ||
            hasAccess(_patientAddress, msg.sender) ||
            (emergencyAccesses[_patientAddress].isActive &&
             emergencyAccesses[_patientAddress].emergencyContact == msg.sender &&
             block.timestamp <= emergencyAccesses[_patientAddress].grantedAt + 24 hours);

        require(allowed, "No access to patient records");
        return patientRecords[_patientAddress];
    }

    function getPatient(address _patientAddress) public view returns (Patient memory) {
        require(patients[_patientAddress].exists, "Patient does not exist");
        return patients[_patientAddress];
    }

    // --- Integrity helpers (hashing) ---

    function getRecordHash(
        string memory _diagnosis,
        string memory _treatment,
        string memory _medications,
        uint256 _date
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_diagnosis, _treatment, _medications, _date));
    }

    function verifyRecordIntegrity(
        address _patientAddress,
        uint256 _recordId,
        bytes32 _expectedHash
    ) public view returns (bool) {
        MedicalRecord memory record = patientRecords[_patientAddress][_recordId];
        bytes32 actualHash = getRecordHash(
            record.diagnosis,
            record.treatment,
            record.medications,
            record.date
        );
        return actualHash == _expectedHash;
    }

    // --- Admin utilities ---

    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Zero address");
        admin = newAdmin;
    }
}
