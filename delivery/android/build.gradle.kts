plugins {
    // Android Gradle Plugin จะถูกประกาศในโมดูล app
    id("com.google.gms.google-services") version "4.4.3" apply false
}

// (ทางเลือก) ย้ายโฟลเดอร์ build ไปไว้ที่อื่น
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    layout.buildDirectory.set(newSubprojectBuildDir)
}

// ไม่จำเป็นต้องบังคับ evaluation ของ :app
// subprojects { evaluationDependsOn(":app") }  <-- ลบได้

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
