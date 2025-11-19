// tests/MedicalRecordsTest.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MedicalRecords", function () {
  let medicalRecords;
  let admin, patient, doctor, emergencyContact;

  beforeEach(async function () {
    [admin, patient, doctor, emergencyContact] = await ethers.getSigners();
    
    const MedicalRecords = await ethers.getContractFactory("MedicalRecords");
    medicalRecords = await MedicalRecords.deploy();
    await medicalRecords.deployed();
  });

  it("Should register a patient", async function () {
    await medicalRecords.connect(admin).registerPatient(
      patient.address, 
      "John Doe", 
      19900101
    );
    
    const patientData = await medicalRecords.getPatient(patient.address);
    expect(patientData.name).to.equal("John Doe");
  });

  it("Should add medical record", async function () {
    await medicalRecords.connect(admin).registerPatient(
      patient.address, 
      "John Doe", 
      19900101
    );

    await medicalRecords.connect(doctor).addMedicalRecord(
      patient.address, 
      "Flu", 
      "Prescribed rest and hydration", 
      Math.floor(Date.now() / 1000)
    );

    const records = await medicalRecords.getMedicalRecords(patient.address);
    expect(records.length).to.equal(1);
    expect(records[0].diagnosis).to.equal("Flu");
  });

  it("Should grant and verify access", async function () {
    await medicalRecords.connect(admin).registerPatient(
      patient.address, 
      "John Doe", 
      19900101
    );

    await medicalRecords.connect(patient).grantAccess(doctor.address);

    const hasAccess = await medicalRecords.connect(doctor).hasAccess(patient.address);
    expect(hasAccess).to.be.true;
    
  });
});