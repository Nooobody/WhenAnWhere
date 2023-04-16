// nodemon -e s -x "node watch.js"
const { exec, spawn } = require("child_process")
const fs = require("fs")

const name = "WhenAnWhere"

if (fs.existsSync(`${name}.nes`)) {
  fs.rmSync(`${name}.nes`)
}

exec(`..\\NESASM3\\NESASM3.exe ${name}.s`, (err, stdout, stderr) => {
  if (err) {
    console.error(err)
    return
  }

  console.log(stderr)
  console.log(stdout)
  console.log('Code assembled!')

  const emu = spawn("..\\nintendulator\\nintendulator.exe", [`${name}.nes`])
})
