// scripts/deploy.js
async function main() {
    const [deployer] = await ethers.getSigners();
  
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());
  
    const MedicalRecords = await ethers.getContractFactory("MedicalRecords");
    const medicalRecords = await MedicalRecords.deploy();
    
    await medicalRecords.deployed();
  
    console.log("MedicalRecords contract deployed to:", medicalRecords.address);
    
    // Save contract address to a file for frontend use
    const fs = require('fs');
    const contractsDir = __dirname + "/../frontend/src/contracts";
  
    if (!fs.existsSync(contractsDir)) {
      fs.mkdirSync(contractsDir, { recursive: true });
    }
  
    fs.writeFileSync(
      contractsDir + "/contract-address.json",
      JSON.stringify({ MedicalRecords: medicalRecords.address }, undefined, 2)
    );
  
    const MedicalRecordsArtifact = artifacts.readArtifactSync("MedicalRecords");
  
    fs.writeFileSync(
      contractsDir + "/MedicalRecords.json",
      JSON.stringify(MedicalRecordsArtifact, null, 2)
    );
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });