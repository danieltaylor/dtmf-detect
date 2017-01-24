React = require('react')
ReactDOM = require('react-dom')

FrequencyRMS = require('./FrequencyRMS.coffee')
FilterThresholdDetector = require('./FilterThresholdDetector.coffee')
BankSelector = require('./BankSelector.coffee')
Coder = require('./Coder.coffee')
BankScreen = require('./BankScreen.coffee')
ResultDisplay = require('./ResultDisplay.coffee')

createAudioContext = ->
  if typeof window.AudioContext isnt 'undefined'
    return new window.AudioContext
  else if typeof window.webkitAudioContext isnt 'undefined'
    return new window.webkitAudioContext

  throw new Error('AudioContext not supported. :(')

context = createAudioContext()

soundBuffer = null

loadData = (url, cb) ->
  request = new XMLHttpRequest()
  request.open 'GET', url, true
  request.responseType = 'arraybuffer'

  request.onload = ->
    context.decodeAudioData request.response, (buffer) ->
      cb buffer

    # silly hack to make sure that screen refreshes on load
    setTimeout (->), 0

  request.send();

keyList = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 'Star', 'Pound' ]

soundBufferList = for x, i in keyList
  do (x, i) ->
    loadData 'tones/dtmf' + x + '.mp3', (data) ->
      soundBufferList[i] = data

  null

# http://dsp.stackexchange.com/questions/15594/how-can-i-reduce-noise-errors-when-detecting-dtmf-with-the-goertzel-algorithm
bankList = for freqSet in [ [ 697, 770, 852, 941 ], [ 1209, 1336, 1477 ] ]
  for freq in freqSet
    new FilterThresholdDetector(new FrequencyRMS(context, freq))

coder = new Coder(new BankSelector(bankList[0]), new BankSelector(bankList[1]), [
  '1', '4', '7', '*'
  '2', '5', '8', '0'
  '3', '6', '9', '#'
])

# @todo connect microphone only to banks and not audio output
testInputNode = context.createDelay()

for bank in bankList
  for detector in bank
    testInputNode.connect detector.rms.audioNode

testInputNode.connect context.destination

runSample = (index) ->
  soundSource = context.createBufferSource()
  soundSource.buffer = soundBufferList[index]
  soundSource.start 0
  soundSource.connect testInputNode

document.addEventListener 'DOMContentLoaded', ->
  document.body.style.textAlign = 'center';

  h = React.createElement

  Demo = () ->
    h 'div', style: {
      display: 'inline-block'
      marginTop: '10px'
    },
    (
      h 'div', style: { display: 'flex', justifyContent: 'center', marginBottom: '30px' }, (
        for keyName, i in keyList
          do (i) ->
            h 'button', key: i, style: { fontSize: '120%' }, onClick: (-> runSample i), 'Key: ' + keyName
      )
    ),
    (
      h BankScreen, bankList: bankList, keyCodeListSet: [
        [ 49, 50, 51, 52 ]
        [ 81, 87, 69, 82 ]
      ], testInputNode: testInputNode, widthPx: 768, heightPx: 512
    ),
    (
      h 'div', style: { height: '10px' }
    ),
    (
      h ResultDisplay, { coder: coder }
    )

  root = document.createElement('div')
  document.body.appendChild(root)

  ReactDOM.render(React.createElement(Demo), root)
