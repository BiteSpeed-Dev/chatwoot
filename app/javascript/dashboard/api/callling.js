import axios from 'axios';
import ApiClient from './ApiClient';

class CallingAPI extends ApiClient {
  startCall({apiKey, token, subDomain, from, to, sid, callerId}) {
    const formData = new FormData();
    formData.append('To', to);
    formData.append('From', from) 
    formData.append('CallerId', callerId)
    formData.append('StatusCallback', 'http://localhost:3000')
    formData.append('StatusCallbackEvents', ['terminal', 'answered'])
    // const url = `https://6e485a1bd4a92babac79988094fc3b21833df0db8d0afdfb:87bcb7510add042ad6fb60c7614544dc6c3b5afbef451cda@api.exotel.com/v1/Accounts/vinayak13/Calls/connect`
    const url = `https://${apiKey}:${token}${subDomain}/v1/Accounts/${sid}/Calls/connect`
    return axios.post(
      url,
      formData
    )
  }
}

export default new CallingAPI();